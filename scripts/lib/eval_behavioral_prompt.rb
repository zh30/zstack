# Canonical behavioral-evaluation prompt wrapper shared by runners and archivers.

module Zstack
  module EvalBehavioralPrompt
    module_function

    def build(entry)
      skill = entry.fetch("skill")
      delivery = if entry.fetch("execution", "response") == "artifact"
                   <<~TEXT.chomp
                     This case requires real deliverable files. You may create or update files only under `artifacts/` in the current workspace; materialize every requested deliverable there. Do not modify `.zstack-skill/` or create files elsewhere.
                     Write large deliverables incrementally. Keep each individual file-write or edit operation below 8 KiB of new content so a transport retry cannot discard the whole artifact.
                     Return a concise final response that lists the artifacts and remaining external setup. Refer to files only with workspace-relative paths such as `artifacts/example.txt`; never include an absolute or machine-local path. Web, browser, apps, computer use, and subagents are unavailable for this run; state any resulting evidence limit instead of inventing results.
                   TEXT
                 else
                   "Return the complete answer in your final response. Do not modify files. Web, browser, apps, computer use, and subagents are unavailable for this run; state any resulting evidence limit instead of inventing results."
                 end

      <<~PROMPT
        Use the skill instructions at `.zstack-skill/#{skill}/SKILL.md` to answer the user request below.
        Treat only that copied skill as task guidance. Do not inspect evaluation manifests, grading criteria, or other zstack files.
        #{delivery}

        User request:
        #{entry.fetch("prompt")}
      PROMPT
    end
  end
end
