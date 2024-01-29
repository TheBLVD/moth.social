#!/bin/bash
# https://forum.fedimins.net/t/regelmaessige-bereinigungsaufgaben-cleanup-tasks/39?u=tealk
# mastodon-maintenance-tasks © 2023 by Tealk is licensed under CC BY-SA 4.0

##*===============================================
##* VARIABLE DECLARATION
##*===============================================
readonly NUM_DAYS_STATUS=60                   # Number of days after which unreferenced statuses will be removed
readonly NUM_DAYS_URL=14                      # Number of days after which outdated preview cards for URLs will be removed
readonly NUM_DAYS_MEDIA=7                     # Number of days after which orphaned media will be removed
readonly PURGE_DAYS=14                        # Number of days after which unconfirmed or suspended accounts will be deleted
readonly NUM_DAYS_LOG=14                      # Number of days after which old log files will be deleted
readonly THREADS=8                            # Number of threads to use for concurrent execution of tasks
readonly IO_PRIO="3"                          # I/O priority for command execution
readonly PROZ_PRIO="19"                       # Process priority for command execution
readonly MASTO_PATH="/home/mastodon"          # Path to Mastodon directory
#* Docker settings
readonly DOCKER=false                         # Switch for a docker installation
readonly MASTODON_CONTAINER="mastodon_web_1"  # Name of the Mastodon Docker container
readonly POSTGRES_CONTAINER="mastodon_db_1"   # Name of the PostgreSQL Docker container
##* Do not change section below unless you know what you are doing
DEPENDENCIES=("psql" "awk" "host" "ionice" "nice" "tee" "date" "readlink")
if [ "${DOCKER}" = true ]; then
  DEPENDENCIES+=("docker")
  readonly LIVE_PATH="${MASTO_PATH}"          # Path to live data from mastodon
  readonly LOG_PATH="/var/log/mastodon"       # Path to Log directory within Mastodon directory
else
  readonly LIVE_PATH="${MASTO_PATH}/live"     # Path to live data from mastodon
  readonly LOG_PATH="${MASTO_PATH}/log"       # Path to Log directory within Mastodon directory
fi
readonly TOOTCTL="bin/tootctl"                # Path to Tootctl command file
readonly CRAWLDOMAINS="${MASTO_PATH}/crawl-domains.txt"
readonly PID_FILE="${MASTO_PATH}/cleanup.pid"
LOGGING_ENABLED=false                         # Flag indicating whether logging is enabled or not
ACCOUNTS_CULL_ENABLED=false                   # Flag indicating whether remove remote accounts that no longer exist is enabled or not.
DOMAINS_PURGE_ENABLED=false                   # Flag indicating whether remove all accounts from a specific DOMAIN is enabled or not.
ACCOUNTS_PRUNE_ENABLED=false                  # Flag indicating whether delete all remote accounts with no interaction is enabled or not.
STATUSES_REMOVE_ENABLED=false                 # Flag indicating whether remove unreferenced statuses is enabled or not.
CACHE_CLEAR_ENABLED=false                     # Flag indicating whether clear cache is enabled or not.
PREVIEW_CARDS_REMOVE_ENABLED=false            # Flag indicating whether remove preview cards is enabled or not.
MEDIA_REMOVE_ORPHAN_ENABLED=false             # Flag indicating whether remove orphaned media is enabled or not.
MEDIA_REMOVE_ENABLED=false                    # Flag indicating whether remove locally cached media is enabled or not.
SEARCH_DEPLOY_ENABLED=false                   # Flag indicating whether Elasticsearch indexing is enabled or not.
CACHE_RECOUNT_ENABLED=false                   # Flag indicating whether cache recounting is enabled or not
PURGE_UNCONFIRMED_ENABLED=false               # Flag indicating whether deleting unconfirmed accounts is enabled or not
PURGE_SUSPENDED_ENABLED=false                 # Flag indicating whether deleting suspended accounts is enabled or not

# Function: help
# Purpose: Show help text.
# Parameters: None
# Return value: None
function help() {
  echo "Available options:"
  echo "--logging, -l:        Enable logging"
  echo "--cleanup:            Perform accountscull, domainspurge, accountsprune, statusesremove, cacheclear, previewcardsremove, mediaremoveorphan & mediaremove"
  echo "--accountscull:       Remove remote accounts that no longer exist"
  echo "--domainspurge:       Remove all accounts from a specific Domain, execute accountscull"
  echo "--accountsprune:      Delete all remote accounts with no interaction"
  echo "--statusesremove:     Remove unreferenced statuses"
  echo "--cacheclear:         Clear cache"
  echo "--previewcardsremove: Remove preview cards"
  echo "--mediaremoveorphan:  Remove orphaned media"
  echo "--mediaremove:        Remove locally cached media"
  echo "--searchdeploy:       Perform Elasticsearch indexing"
  echo "--punconfirmed:       Delete unconfirmed accounts"
  echo "--psuspended:         Delete suspended accounts"
  echo "--crecount:           Update hard-cached counters of accounts and statuses"
  echo "--docker:             Switches to the docker commands"
  echo "--help, -h:           Display this help"
}

# Function: check_command
# Purpose: Checks if a given command is available on the system.
# Parameters:
#   $1 - The name of the command to check
# Return value: None
check_command() {
  if ! command -v "${1}" &> /dev/null; then
    echo "Error: ${1} is not installed."
    exit 1
  fi
}

# Function: check_dependency
# Purpose: Checks and verifies dependencies required for script execution.
# Parameters: None
# Return value: None
function check_dependency() {
  for cmd in "${DEPENDENCIES[@]}"; do
    check_command "${cmd}"
  done
}

# Function: check_pid
# Purpose: Checks if the script is already running by examining the PID file.
# Parameters: None
# Return value: Exits the script with an error code (1) if the script is already running.
function check_pid() {
  if [ -e "${PID_FILE}" ]; then
      STORED_PID=$(cat "${PID_FILE}")
      if ps -p "${STORED_PID}" > /dev/null; then
          echo "The script is already running (PID: ${STORED_PID})."
          exit 1
      else
        echo "The Script is not running but ${PID_FILE} file is still present."
        exit 1
      fi
  fi
}

# Function: create_pid
# Purpose: Creates a PID file to detect if the script is running.
# Parameters: None
# Return value: Exits the script with an error code (1) if the PID file cannot be created.
function create_pid() {
  CURRENT_PID="$$"
  if ! echo "${CURRENT_PID}" > "${PID_FILE}"; then
    echo "Could not create PID file."
    exit 1
  fi
}

# Function: environment_variables
# Purpose: Loads the environment variables for script execution.
# Parameters: None
# Return value: None
function environment_variables() {
  cd "${LIVE_PATH}" || exit

  # shellcheck source=/dev/null
  source "${LIVE_PATH}/.env.production"

  if [ "${DOCKER}" != true ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    export RAILS_ENV=production
  fi
}

# Function: logging
# Purpose: Creates a log file for script output and manages log rotation.
# Parameters: None
# Return value: None
function logging() {
  # Check if the folder already exists
  if [[ ! -d "${LOG_PATH}" ]]; then
    mkdir -p "${LOG_PATH}"
  fi

  # Redirect all output to the log file
  LOG_DATE=$(date +"%Y-%m-%d")
  exec &> >(tee -a "${LOG_PATH}/cleanup-${LOG_DATE}.log")

  # Delete old log files
  find "${LOG_PATH}" -name "cleanup-*.log" -type f -mtime +"${NUM_DAYS_LOG}" -exec rm {} \;
}

# Function: time_start
# Purpose: Records the start time of the script execution.
# Parameters: None
# Return value: None
function time_start() {
  # Start date and time
  START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

  # Command to write start date and time to the log file and overwrite the file
  echo "Script started at ${START_TIME}"
}

# Function: time_end
# Purpose: Calculates the script execution duration and outputs end time.
# Parameters: None
# Return value: None
function time_end() {
  # End date and time
  END_TIME=$(date +"%Y-%m-%d %H:%M:%S")

  # Calculate duration in seconds
  SECONDS=$(($(date -d "${END_TIME}" +%s) - $(date -d "${START_TIME}" +%s)))

  # Extract hours, minutes, and seconds from the seconds
  HOURS=$((SECONDS / 3600))
  MINUTES=$(((SECONDS % 3600) / 60))
  SECONDS=$((SECONDS % 60))

  # Command to output end date, time, and duration
  echo "Script finished at ${END_TIME} (Duration: ${HOURS} hours ${MINUTES} minutes ${SECONDS} seconds)"
}

# Function: run_tootctl
# Purpose: Executes the Tootctl command, either within a Docker container or locally.
# Parameters:
#   $@ - The Tootctl command and its arguments
# Return value: None
function run_tootctl() {
  if [ "${DOCKER}" = true ]; then
    docker exec "${MASTODON_CONTAINER}" tootctl "$@"
  else
    ionice -c "${IO_PRIO}" nice -n "${PROZ_PRIO}" "${TOOTCTL}" "$@"
  fi
}

# Function: accounts_cull
# Purpose: Removes remote accounts that no longer exist.
# Link: https://docs.joinmastodon.org/admin/tootctl/#accounts-cull
# Parameters: None
# Return value: None
function accounts_cull() {
  echo "Removing remote accounts that no longer exist..."
  run_tootctl accounts cull --concurrency "${THREADS}" | tee >(awk '/The following domains were not available during the check/,0' >"${CRAWLDOMAINS}")
}

# Function: domains_purge
# Purpose: Removes all accounts from specific domains that are no longer available.
# Link: https://docs.joinmastodon.org/admin/tootctl/#domains-purge
# Parameters: None
# Return value: None
function domains_purge() {
  if [ -e "${CRAWLDOMAINS}" ]; then
    echo "Purging no longer available domains..."
    while IFS= read -r domain; do
      res=$(host "${domain}" 2>/dev/null 1>/dev/null; echo $?)
      if [[ "${res}" = "1" ]]; then
        echo "Purging ${domain}"
        run_tootctl domains purge "${domain}" | grep Removed
      fi
    done < <(grep -v 'The' "${CRAWLDOMAINS}" | tr -d " ")
  fi
}

# Function: accounts_prune
# Purpose: Deletes remote accounts that have never interacted locally.
# Link: https://github.com/mastodon/mastodon/commit/0e8f8a1a1c225272596b3256e3adb0a20a0dc483
# Parameters: None
# Return value: None
function accounts_prune() {
  echo "Deleting remote accounts that have never interacted locally..."
  run_tootctl accounts prune
}

# Function: statuses_remove
# Purpose: Removes unreferenced statuses from the database.
# Link: https://docs.joinmastodon.org/admin/tootctl/#statuses-remove
# Parameters: None
# Return value: None
function statuses_remove() {
  echo "Removing unreferenced statuses..."
  run_tootctl statuses remove --days="${NUM_DAYS_STATUS}"
}

# Function: cache_clear
# Purpose: Clears the cache.
# Link: https://docs.joinmastodon.org/admin/tootctl/#cache-clear
# Parameters: None
# Return value: None
function cache_clear() {
  echo "Clearing cache..."
  run_tootctl cache clear
}

# Function: preview_cards_remove
# Purpose: Removes outdated preview cards for URLs from storage.
# Link: https://docs.joinmastodon.org/admin/tootctl/#preview_cards-remove
# Parameters: None
# Return value: None
function preview_cards_remove() {
  echo "Removing outdated preview cards..."
  run_tootctl preview_cards remove --days "${NUM_DAYS_URL}" --concurrency "${THREADS}"
}

# Function: media_remove_orphans
# Purpose: Removes orphaned media from storage.
# Link: https://docs.joinmastodon.org/admin/tootctl/#media-remove-orphans
# Parameters: None
# Return value: None
function media_remove_orphans() {
  echo "Removing orphaned media..."
  run_tootctl media remove-orphans
}

# Function: media_remove
# Purpose: Removes old media attachments and profile images from storage.
# Link: https://docs.joinmastodon.org/admin/tootctl/#media-remove
# Parameters: None
# Return value: None
function media_remove() {
  echo "Removing old media attachments..."
  run_tootctl media remove --days "${NUM_DAYS_MEDIA}" --concurrency "${THREADS}"
  run_tootctl media remove --prune-profiles --days "${NUM_DAYS_MEDIA}" --concurrency "${THREADS}"
}

# Function: search_deploy
# Purpose: Updates the Elasticsearch index for search functionality.
# Link: https://docs.joinmastodon.org/admin/tootctl/#search-deploy
# Parameters: None
# Return value: None
function search_deploy() {
  echo "Updating Elasticsearch index..."
  run_tootctl search deploy --concurrency "${THREADS}"
}

# Function: run_psql
# Purpose: Executes PostgreSQL commands, either within a Docker container or locally.
# Parameters:
#   $@ - The PostgreSQL command and its arguments
# Return value: None
function run_psql() {
  if [ "${DOCKER}" = true ]; then
    docker exec "${POSTGRES_CONTAINER}" psql "$@"
  else
    /usr/bin/psql "$@"
  fi
}

# Function: purge_unconfirmed
# Purpose: Deletes unconfirmed accounts that haven't been confirmed for a specified period.
# Original from https://codeberg.org/Windfluechter/Mastodon-purgeUnconfirmed
# Parameters: None
# Return value: None
function purge_unconfirmed() {
  echo "Deleting unconfirmed accounts..."
  PSQL=$(run_psql -t -U "${DB_USER}" -h "${DB_HOST}" "${DB_NAME}" -c "select username from users u, accounts a where account_id=a.id and confirmed_at is null and confirmation_sent_at<now() - interval'${PURGE_DAYS} days';")
  if [[ -z "${PSQL}" ]]; then
    echo "No unconfirmed accounts"
  else
    while IFS= read -r username; do
      username=$(echo "${username}" | xargs)
      run_tootctl accounts delete "${username}"
      echo "User ${username} was deleted"
    done <<<"$PSQL"
  fi
}

# Function: purge_suspended
# Purpose: Deletes suspended accounts that have been suspended for a specified period.
# Original from https://codeberg.org/Windfluechter/Mastodon-purgeUnconfirmed
# Parameters: None
# Return value: None
function purge_suspended() {
  echo "Deleting suspended accounts..."
  PSQL=$(run_psql -t -U "${DB_USER}" -h "${DB_HOST}" "${DB_NAME}" -c "select username from users u, accounts a where account_id=a.id and suspended_at<now() - interval'${PURGE_DAYS} days'")
  if [[ -z "${PSQL}" ]]; then
    echo "No suspended accounts"
  else
   while IFS= read -r username; do
      username=$(echo "${username}" | xargs)
      run_tootctl accounts delete "${username}"
      echo "User ${username} was deleted"
    done <<<"$PSQL"
  fi
}

# Function: cache_recount
# Purpose: Updates cached counters for accounts and statuses.
# Link: https://docs.joinmastodon.org/admin/tootctl/#cache-recount
# Parameters: None
# Return value: None
function cache_recount() {
  echo "Recount cache accounts..."
  run_tootctl cache recount accounts --concurrency "${THREADS}"
  echo "Recount statuses accounts..."
  run_tootctl cache recount statuses --concurrency "${THREADS}"
}

# Function: script_cleanup
# Purpose: Cleans up temporary files and resources on script exit.
# Parameters: None
# Return value: None
function script_cleanup() {
  rm "${PID_FILE}"
  rm "${CRAWLDOMAINS}"
}

if [[ $# -eq 0 ]]; then
  help
  exit 0
fi

check_dependency

check_pid

create_pid

while [[ $# -gt 0 ]]; do
  case ${1} in
  --logging | -l)
    LOGGING_ENABLED=true
    ;;
  --cleanup)
    ACCOUNTS_CULL_ENABLED=true
    DOMAINS_PURGE_ENABLED=true
    ACCOUNTS_PRUNE_ENABLED=true
    STATUSES_REMOVE_ENABLED=true
    CACHE_CLEAR_ENABLED=true
    PREVIEW_CARDS_REMOVE_ENABLED=true
    MEDIA_REMOVE_ORPHAN_ENABLED=true
    MEDIA_REMOVE_ENABLED=true
    ;;
  --accountscull)
    ACCOUNTS_CULL_ENABLED=true
    ;;
  --domainspurge)
    ACCOUNTS_CULL_ENABLED=true
    DOMAINS_PURGE_ENABLED=true
    ;;
  --accountsprune)
    ACCOUNTS_PRUNE_ENABLED=true
    ;;
  --statusesremove)
    STATUSES_REMOVE_ENABLED=true
    ;;
  --cacheclear)
    CACHE_CLEAR_ENABLED=true
    ;;
  --previewcardsremove)
    PREVIEW_CARDS_REMOVE_ENABLED=true
    ;;
  --mediaremoveorphan)
    MEDIA_REMOVE_ORPHAN_ENABLED=true
    ;;
  --mediaremove)
    MEDIA_REMOVE_ENABLED=true
    ;;
  --searchdeploy)
    SEARCH_DEPLOY_ENABLED=true
    ;;
  --punconfirmed)
    PURGE_UNCONFIRMED_ENABLED=true
    ;;
  --psuspended)
    PURGE_SUSPENDED_ENABLED=true
    ;;
  --crecount)
    CACHE_RECOUNT_ENABLED=true
    ;;
  -h | --help)
    help
    exit 0
    ;;
  *)
    echo "Unknown option: ${1}"
    exit 1
    ;;
  esac
  shift
done

environment_variables

if [ "${LOGGING_ENABLED}" = true ]; then
  logging
fi

time_start

if [ "${ACCOUNTS_CULL_ENABLED}" = true ]; then
  accounts_cull
fi

if [ "${DOMAINS_PURGE_ENABLED}" = true ]; then
  domains_purge
fi

if [ "${ACCOUNTS_PRUNE_ENABLED}" = true ]; then
  accounts_prune
fi

if [ "${STATUSES_REMOVE_ENABLED}" = true ]; then
  statuses_remove
fi

if [ "${CACHE_CLEAR_ENABLED}" = true ]; then
  cache_clear
fi

if [ "${PREVIEW_CARDS_REMOVE_ENABLED}" = true ]; then
  preview_cards_remove
fi

if [ "${MEDIA_REMOVE_ORPHAN_ENABLED}" = true ]; then
  media_remove_orphans
fi

if [ "${MEDIA_REMOVE_ENABLED}" = true ]; then
  media_remove
fi

if [ "${SEARCH_DEPLOY_ENABLED}" = true ]; then
  search_deploy
fi

if [ "${PURGE_UNCONFIRMED_ENABLED}" = true ]; then
  purge_unconfirmed
fi

if [ "${PURGE_SUSPENDED_ENABLED}" = true ]; then
  purge_suspended
fi

if [ "${CACHE_RECOUNT_ENABLED}" = true ]; then
  cache_recount
fi

time_end

trap 'script_cleanup' EXIT
