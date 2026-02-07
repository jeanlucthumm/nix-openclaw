# Documents and skills implementation for NixOS module
#
# Parallel implementation to home-manager's documents/skills handling.
# TODO: Consolidate with home-manager into shared lib once patterns stabilize.

{ lib, pkgs, cfg, instanceConfigs, toolSets }:

let
  documentsEnabled = cfg.documents != null;

  # Render a skill to markdown with frontmatter
  renderSkill = skill:
    let
      metadataLine =
        if skill.openclaw != null
        then "metadata: ${builtins.toJSON { openclaw = skill.openclaw; }}"
        else null;
      homepageLine =
        if skill.homepage != null
        then "homepage: ${skill.homepage}"
        else null;
      frontmatterLines = lib.filter (line: line != null) [
        "---"
        "name: ${skill.name}"
        "description: ${skill.description}"
        homepageLine
        metadataLine
        "---"
      ];
      frontmatter = lib.concatStringsSep "\n" frontmatterLines;
      body = skill.body or "";
    in
      "${frontmatter}\n\n${body}\n";

  # Generate tools report (appended to TOOLS.md)
  toolsReport =
    let
      toolNames = toolSets.toolNames or [];
      reportLines = [
        "<!-- BEGIN NIX-REPORT -->"
        ""
        "## Nix-managed tools"
        ""
        "### Built-in toolchain"
      ]
      ++ (if toolNames == [] then [ "- (none)" ] else map (name: "- " + name) toolNames)
      ++ [
        ""
        "<!-- END NIX-REPORT -->"
      ];
    in
      lib.concatStringsSep "\n" reportLines;

  toolsWithReport =
    if documentsEnabled then
      pkgs.runCommand "openclaw-tools-with-report.md" {} ''
        cat ${cfg.documents + "/TOOLS.md"} > $out
        echo "" >> $out
        cat <<'EOF' >> $out
${toolsReport}
EOF
      ''
    else
      null;

  # Assertions for documents
  documentsAssertions = lib.optionals documentsEnabled [
    {
      assertion = builtins.pathExists cfg.documents;
      message = "services.openclaw.documents must point to an existing directory.";
    }
    {
      assertion = builtins.pathExists (cfg.documents + "/AGENTS.md");
      message = "Missing AGENTS.md in services.openclaw.documents.";
    }
    {
      assertion = builtins.pathExists (cfg.documents + "/SOUL.md");
      message = "Missing SOUL.md in services.openclaw.documents.";
    }
    {
      assertion = builtins.pathExists (cfg.documents + "/TOOLS.md");
      message = "Missing TOOLS.md in services.openclaw.documents.";
    }
  ];

  # Partition skills into derivation-based (from skill library) and inline (submodule)
  isSkillDrv = s: s ? isOpenclawSkill && s.isOpenclawSkill;
  drvSkills = lib.filter isSkillDrv cfg.skills;
  inlineSkills = lib.filter (s: !(isSkillDrv s)) cfg.skills;

  # Assertions for skills
  secretAssertions = lib.flatten (map (s:
    let nullSecrets = lib.attrNames (lib.filterAttrs (_: v: v == null) (s.secrets or {}));
    in map (name: {
      assertion = false;
      message = "services.openclaw.skills: skill '${s.skillName}' has null secret '${name}' — provide a file path.";
    }) nullSecrets
  ) drvSkills);

  skillAssertions =
    let
      drvNames = map (s: s.skillName) drvSkills;
      inlineNames = map (s: s.name) inlineSkills;
      names = drvNames ++ inlineNames;
      nameCounts = lib.foldl' (acc: name: acc // { "${name}" = (acc.${name} or 0) + 1; }) {} names;
      duplicateNames = lib.attrNames (lib.filterAttrs (_: v: v > 1) nameCounts);
      copySkillsWithoutSource = lib.filter (s: s.mode == "copy" && s.source == null) inlineSkills;
    in
      (if duplicateNames == [] then [] else [
        {
          assertion = false;
          message = "services.openclaw.skills has duplicate names: ${lib.concatStringsSep ", " duplicateNames}";
        }
      ])
      ++ (map (s: {
        assertion = false;
        message = "services.openclaw.skills: skill '${s.name}' uses copy mode but has no source.";
      }) copySkillsWithoutSource)
      ++ secretAssertions;

  # Build skill derivations for each instance
  # Returns: { "<instanceName>" = [ { path = "skills/<name>"; drv = <derivation>; } ... ]; }
  skillDerivations =
    lib.mapAttrs (instName: instCfg:
      let
        drvEntries = map (skill: {
          path = "skills/${skill.skillName}";
          drv = skill;
          mode = "copy";
        }) drvSkills;
        inlineEntries = map (skill:
          let
            skillDrv = if skill.mode == "inline" then
              pkgs.writeTextDir "SKILL.md" (renderSkill skill)
            else
              # copy mode - use the source directly
              skill.source;
          in {
            path = "skills/${skill.name}";
            drv = skillDrv;
            mode = skill.mode;
          }
        ) inlineSkills;
      in drvEntries ++ inlineEntries
    ) instanceConfigs;

  # Build documents derivations for each instance
  # Returns: { "<instanceName>" = { agents = <drv>; soul = <drv>; tools = <drv>; } or null; }
  documentsDerivations =
    if !documentsEnabled then
      lib.mapAttrs (_: _: null) instanceConfigs
    else
      lib.mapAttrs (instName: instCfg: {
        agents = cfg.documents + "/AGENTS.md";
        soul = cfg.documents + "/SOUL.md";
        tools = toolsWithReport;
      }) instanceConfigs;

  # Generate tmpfiles rules for skills and documents
  tmpfilesRules =
    let
      rulesForInstance = instName: instCfg:
        let
          workspaceDir = instCfg.workspaceDir;
          skillRules = map (entry:
            "L+ ${workspaceDir}/${entry.path} - ${cfg.user} ${cfg.group} - ${entry.drv}"
          ) (skillDerivations.${instName} or []);
          docRules = if documentsDerivations.${instName} == null then [] else
            let docs = documentsDerivations.${instName}; in [
              "C ${workspaceDir}/AGENTS.md 0640 ${cfg.user} ${cfg.group} - ${docs.agents}"
              "C ${workspaceDir}/SOUL.md 0640 ${cfg.user} ${cfg.group} - ${docs.soul}"
              "C ${workspaceDir}/TOOLS.md 0640 ${cfg.user} ${cfg.group} - ${docs.tools}"
            ];
        in
          skillRules ++ docRules;
    in
      lib.flatten (lib.mapAttrsToList rulesForInstance instanceConfigs);

in {
  inherit documentsAssertions skillAssertions tmpfilesRules drvSkills;
}
