# Screenpipe per-run JSON events use the existing LLM index. Splunk extracts
# each run's fields with spath; the source path retains the pipe name.
{
  "pipelines/screenpipe_pipe_runs/conf.yml" = ''
    output: default
    functions:
      - id: eval
        filter: "true"
        conf:
          add:
            - name: index
              value: "'llm'"
            - name: sourcetype
              value: "'screenpipe:pipe_run'"
  '';
}
