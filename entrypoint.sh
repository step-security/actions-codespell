#!/bin/sh

REPO_PRIVATE=$(jq -r '.repository.private | tostring' "$GITHUB_EVENT_PATH" 2>/dev/null || echo "")
UPSTREAM="codespell-project/actions-codespell"
ACTION_REPO="${GITHUB_ACTION_REPOSITORY:-}"
DOCS_URL="https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions"

echo ""
echo -e "\033[1;36mStepSecurity Maintained Action\033[0m"
echo "Secure drop-in replacement for $UPSTREAM"
if [ "$REPO_PRIVATE" = "false" ]; then
  echo -e "\033[32m✓ Free for public repositories\033[0m"
fi
echo -e "\033[36mLearn more:\033[0m $DOCS_URL"
echo ""

if [ "$REPO_PRIVATE" != "false" ]; then
  SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"

  if [ "$SERVER_URL" != "https://github.com" ]; then
    BODY=$(printf '{"action":"%s","ghes_server":"%s"}' "$ACTION_REPO" "$SERVER_URL")
  else
    BODY=$(printf '{"action":"%s"}' "$ACTION_REPO")
  fi

  API_URL="https://agent.api.stepsecurity.io/v1/github/$GITHUB_REPOSITORY/actions/maintained-actions-subscription"

  RESPONSE=$(curl --max-time 3 -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$API_URL" -o /dev/null) && CURL_EXIT_CODE=0 || CURL_EXIT_CODE=$?

  if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "Timeout or API not reachable. Continuing to next step."
  elif [ "$RESPONSE" = "403" ]; then
    echo -e "::error::\033[1;31mThis action requires a StepSecurity subscription for private repositories.\033[0m"
    echo -e "::error::\033[31mLearn how to enable a subscription: $DOCS_URL\033[0m"
    exit 1
  fi
fi

# Copy the matcher directly to RUNNER_TEMP; the /github/workflow bind-mount is not reliable.
CODE_DIR="${CODE_DIR:-/code}"
mkdir -p "${RUNNER_TEMP}/_github_workflow"
cp "${CODE_DIR}/codespell-matcher.json" "${RUNNER_TEMP}/_github_workflow/codespell-matcher.json"
echo "::add-matcher::${RUNNER_TEMP}/_github_workflow/codespell-matcher.json"

# Run codespell.
# The weird piping was needed because we want to get the exitcode from codespell,
# but there is no other good universal way of doing so.
# e.g. PIPESTATUS and pipestatus only work in bash/zsh respectively.
echo "Running codespell on '${INPUT_PATH}' with the following options..."
command_args=""
echo "Builtin dictionaries '${INPUT_BUILTIN}'"
if [ "x${INPUT_BUILTIN}" != "x" ]; then
    command_args="${command_args} --builtin ${INPUT_BUILTIN}"
fi
echo "Check filenames? '${INPUT_CHECK_FILENAMES}'"
if [ -n "${INPUT_CHECK_FILENAMES}" ]; then
    echo "Checking filenames"
    command_args="${command_args} --check-filenames"
fi
echo "Check hidden? '${INPUT_CHECK_HIDDEN}'"
if [ -n "${INPUT_CHECK_HIDDEN}" ]; then
    echo "Checking hidden"
    command_args="${command_args} --check-hidden"
fi
echo "Config '${INPUT_CONFIG}'"
if [ "x${INPUT_CONFIG}" != "x" ]; then
    command_args="${command_args} --config ${INPUT_CONFIG}"
fi
echo "Exclude file '${INPUT_EXCLUDE_FILE}'"
if [ "x${INPUT_EXCLUDE_FILE}" != "x" ]; then
    command_args="${command_args} --exclude-file ${INPUT_EXCLUDE_FILE}"
fi
echo "Ignore words file '${INPUT_IGNORE_WORDS_FILE}'"
if [ "x${INPUT_IGNORE_WORDS_FILE}" != "x" ]; then
    command_args="${command_args} --ignore-words ${INPUT_IGNORE_WORDS_FILE}"
fi
echo "Ignore words list '${INPUT_IGNORE_WORDS_LIST}'"
if [ "x${INPUT_IGNORE_WORDS_LIST}" != "x" ]; then
    command_args="${command_args} --ignore-words-list ${INPUT_IGNORE_WORDS_LIST}"
fi
echo "Ignore URI words list '${INPUT_URI_IGNORE_WORDS_LIST}'"
if [ "x${INPUT_URI_IGNORE_WORDS_LIST}" != "x" ]; then
    command_args="${command_args} --uri-ignore-words-list ${INPUT_URI_IGNORE_WORDS_LIST}"
fi
echo "Skipping '${INPUT_SKIP}'"
if [ "x${INPUT_SKIP}" != "x" ]; then
    command_args="${command_args} --skip ${INPUT_SKIP}"
fi
echo "Resulting CLI options ${command_args}"
exec 5>&1
res=`{ { codespell --count ${command_args} ${INPUT_PATH}; echo $? 1>&4; } 1>&5; } 4>&1`
if [ "$res" = "0" ]; then
    echo "Codespell found no problems"
else
    echo "Codespell found one or more problems"
fi

# Remove the matchers, so no other jobs hit them.
echo "::remove-matcher owner=codespell-matcher-default::"
echo "::remove-matcher owner=codespell-matcher-specified::"

# If we are in warn-only mode, return always as if we pass
if [ -n "${INPUT_ONLY_WARN}" ]; then
    exit 0
else
    exit $res
fi
