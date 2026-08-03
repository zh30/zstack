# Canonical description-only routing prompt shared by runners and coverage audits.

module Zstack
  module EvalRoutingPrompt
    module_function

    def wrapper_style(option, user_prompt)
      return option unless option == "auto"

      user_prompt.match?(/\p{Han}/) ? "zh" : "en"
    end

    def build(candidates, user_prompt, style, description_limit = nil)
      candidate_text = candidates.map { |id, description| "- #{id}: #{description}" }.join("\n")
      if style == "zh"
        stress = if description_limit
                   "这些描述已机械截断为前 #{description_limit} 个 Unicode 字符，用于上下文预算压力测试。\n"
                 else
                   ""
                 end
        <<~PROMPT
          只根据下面候选 skill 的 frontmatter 描述，为一个用户请求选择路由。#{stress}不要使用工具、读取文件或加载已安装的 skill 正文。

          候选 skills：
          #{candidate_text}

          用户请求：
          #{user_prompt}

          严格只回复两行：
          selection: <一个候选 id 或 none>
          reason: <一句简短中文理由>
        PROMPT
      else
        stress = if description_limit
                   "These descriptions have been mechanically tail-truncated to #{description_limit} Unicode characters for a context-budget stress test.\n"
                 else
                   ""
                 end
        <<~PROMPT
          Route one user request using only the candidate frontmatter descriptions below. #{stress}Do not use tools, inspect files, or load installed skill bodies.

          Candidate skills:
          #{candidate_text}

          User request:
          #{user_prompt}

          Reply with exactly two lines:
          selection: <one candidate id or none>
          reason: <one concise sentence>
        PROMPT
      end
    end
  end
end
