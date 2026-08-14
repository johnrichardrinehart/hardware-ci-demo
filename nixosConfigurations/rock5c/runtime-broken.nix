_:

{
  system.preSwitchChecks.demoRuntimeFailure = ''
    if [ "''${2-}" = switch ]; then
      echo >&2 "Intentional demo failure: refusing runtime activation."
      exit 1
    fi
  '';
}
