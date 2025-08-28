
# General



## Urgent Project Directives
- Project uses BashFX Build.sh pattern, all live code is in `./parts` and output created with `./build.sh`
- Do not ever read the project output `padlock.sh` file directly, it may be huge. 
- Be smart about token economy and context window usage, use analysis tools and fine grain tools instead of blunt force reading whenever possible.
- You are welcome to create general use or important infra tooling, we store these in `./xbin`
- Per BashFX using only XDG+ temp `~/.cache/tmp` is preferred over `/tmp`
- Do not pollute the project root space, all agentic proto-work must be in the prescribed `./agents` directory

## Urgent Tools & Strategires
- User Provided Tools:
    - `build.sh` is available in most BashFX projects, when present must be used to build output file. If build.sh is broken or fails this is a critical blocking issue.
    - `func` is for powerful shell function analysis and editing, and provides a sandboxed workflow for directly editing functions through function files;
       has efficient analysis tools like `func ls <src>` to list all shell functions in a file, and `func spy <function> <src>` which will dump the function contents.
       its editing tools and workflow is the preferred method for editing functions, please use `func help` command for the full api.
    - `gitsim` used in conjunction with ad hoc, smoke and integration testing, can create virtual home environments and virtual git projects. Use `gitsim help` for the full api.
    - `taskdb.sh` is our new simple task dashboard. 

## Agent Team vs Single Agent
- SINGLE_MODE: in this mode you are responsible for all roles of a project, only you and the user are working. This is the default mode.
- TEAM_MODE: in this mode multiple agents work together, the available team members may vary
    - DEFINED_AGENTS:
      - @OXX (orchestrator)
      - @PRD (product) 
      - @LSE (engineer) 
      - @AA (analyst)
      - @QA (testing) 
      - @RRR (research)
    - TEAM_CONFIG: defines varied team configs that may be active
      - SIMPLE_TEAM: @OXX, @LSE, @QA 
      - COMPLEX_TEAM: SIMPLE_TEAM + @PRD
      - POWER_TEAM: COMPLEX_TEAM + @AA
      - SMART_TEAM: POWER_TEAM + @RR
      
## Import Team Communication Protocol
- in all TEAM_MODEs, all agents must communicate their status changes
    - directly to @OXX!
    - to their neighbor agent in their pipeline (if applicable)
    - or to their stakeholder agent(s) who may be waiting for deliverables or dependencies
        - Examples (non exhaustive)
            - @LSE must tell @AA and @QA when dev work is ready
            - @QA must tell @PRD when task is tested and completed
            - @RRR must tell waiting stakeholder(s) when research is completed
- the very important `./agents/ITERATION.md` file indicates the standard iteration work flow protocol, but may be updated as needed

## Agents Directory Usage
- the agents directory `./agents` holds all agent orchestration related docs
- RESARCH: `./agents/reserch` holds `RX_*.md` research findings created by @RRR or other agents
- OBSERVATIONS: `./agents/observations` holds `{AGENT}_OBSERVATIONS.md` insight files observed by all agents
- SCRIPTS: `./agents/scripts` holds any ephemeral/ad-hoc testing/experiment scripts created by agents
- ARCHIVE: `./agents/archive` holds legacy reference files the user is not sure is needed or not
- CACHE: `./agents/cache` holds query/read output, ephemeral and shared storage for agents.
- any `{AGENT}*md` file indicates an information file for that particular agent
- always cleanup ephemeral files when no longer needed. Research and Observation files are permanent and must be preserved.

## Docs Directory 
- holds permanent reference docs like architectures and concepts
- `./docs/priv` directory is off limits
