# Cleanup Tasks Script from https://codeberg.org/Fedimins/mastodon-maintenance-tasks

This script performs regular cleanup tasks for the Mastodon system. It removes remote accounts, unreferenced statuses, obsolete thumbnails and media attachments, and updates the Elasticsearch index.

## Usage

1. download the script and save it to a suitable location on your Mastodon server.

```bash
curl -o /home/mastodon/cleanup_tasks.sh https://codeberg.org/Fedimins/mastodon-maintenance-tasks/raw/branch/master/cleanup_tasks.sh
```

2. make the script executable:

```bash
sudo chmod +x /home/mastodon/cleanup_tasks.sh
```

4. (docker) if you don't run the script as root you have to create the log folder

```bash
sudo mkdir /var/log/mastodon
sudo chown mastodon:mastodon /var/log/mastodon
```

5. run the script:

```bash
sudo -u mastodon bash /home/mastodon/cleanup_tasks.sh [OPTIONS]
```

### Options

- `--help`, `-h`: Show this help message.
- `--logging`, `-l`: Enable logging.
- `--cleanup`: Performs: accountscull, domainspurge, accountsprune, statusesremove, cacheclear, previewcardsremove, mediaremoveorphan & mediaremove.
- `--accountscull`: Remove remote accounts that no longer exist"
- `--domainspurge`: Remove all accounts from a specific Domain, execute accountscull"
- `--accountsprune`: Delete all remote accounts with no interaction"
- `--statusesremove`: Remove unreferenced statuses"
- `--cacheclear`: Clear cache"
- `--previewcardsremove`: Remove preview cards"
- `--mediaremoveorphan`: Remove orphaned media"
- `--mediaremove`: Remove locally cached media"
- `--searchdeploy`: Perform Elasticsearch indexing
- `--punconfirmed`: Purge unconfirmed entries.
- `--psuspended`: Purge suspended entries.
- `--crecount`: Update hard-cached counters of accounts and statuses
- `--docker`: Switches to the docker commands.

Note: If no parameter or logging is specified, the cleanup is always executed, if it is to be executed in combination with the purge jobs it must be specified.

```
Examples:
./cleanup_tasks.sh --help
./cleanup_tasks.sh --punconfirmed
./cleanup_tasks.sh -l --psuspended
./cleanup_tasks.sh -l --psuspended --cleanup
```

### Set up as a cron job

You can set up the cleanup script as a cron job to run the cleanup tasks automatically on a regular basis.

1. open the terminal and run the following command to edit the cron job of the "mastodon" user:

```bash
crontab -u mastodon -e
```

2. add the following line to the end of the file to set up the cron job:

```bash
0 3 * * * /home/mastodon/cleanup_tasks.sh -l --cleanup
```

In this example, the cron job is run daily at 3:00 AM and the output is written to a log file. Make sure you change the path to the `cleanup_tasks.sh` script to match your actual location. 3.

Save the file and close the text editor.

The cron job is now set up and will run automatically according to the specified schedule. The output will be logged in the log file you enabled by the `-l` switch in the script.

Please note that you can customize the scheduling in the cron job to your specific needs. For more information on configuring cron jobs, see the [Cron documentation](https://linux.die.net/man/5/crontab).

### Set up as a systemd timer

1. open a terminal window.

2. download the .service file and save it as `mastodon-cleanup.service`:

```bash
curl -o /etc/systemd/system/mastodon-cleanup.service https://codeberg.org/Fedimins/mastodon-maintenance-tasks/raw/branch/master/mastodon-cleanup.service
```

3. download the .timer file and save it as `mastodon-cleanup.timer`:

```bash
curl -o /etc/systemd/system/mastodon-cleanup.timer https://codeberg.org/Fedimins/mastodon-maintenance-tasks/raw/branch/master/mastodon-cleanup.timer
```

4. update the permissions of the downloaded files to make sure they are executable:

```bash
sudo chmod 644 /etc/systemd/system/mastodon-cleanup.service
sudo chmod 644 /etc/systemd/system/mastodon-cleanup.timer
```

5 [Optional] Open the .timer file in a text editor and insert the following content:

Replace `OnCalendar=daily` with the desired time in the format `OnCalendar=HH-MM-SS` at which the cron job should run.

6. update the systemd service directory to reflect the new changes:

```bash
sudo systemctl daemon-reload
```

7. start the timer and enable it to start automatically at system startup:

```bash
sudo systemctl enable --now mastodon-cleanup.timer
```

## Configuration

You can customize certain parameters in the script to meet your requirements. These parameters can be found at the beginning of the script under the heading "VARIABLE DECLARATION". For example, here you can change the number of days to keep statuses, URLs and media attachments.

```bash
NUM_DAYS_STATUS=60             # Number of days after which unreferenced statuses will be removed
NUM_DAYS_URL=14                # Number of days after which outdated preview cards for URLs will be removed
NUM_DAYS_MEDIA=7               # Number of days after which orphaned media will be removed
PURGE_DAYS=14                  # Number of days after which unconfirmed or suspended accounts will be deleted
NUM_DAYS_LOG=14                # Number of days after which old log files will be deleted
THREADS=8                      # Number of threads to use for concurrent execution of tasks
IO_PRIO="3"                    # I/O priority for command execution
PROZ_PRIO="19"                 # Process priority for command execution
MASTO_PATH="/home/mastodon"    # Path to Mastodon directory
```

Please note that changes to the variables should be done carefully to make sure they fit your Mastodon configuration.

## Contribute

If you have suggestions for improving the script or have found bugs, feel free to contribute. Just open an issue or send a pull request with your changes.

## License

[mastodon-maintenance-tasks](https://codeberg.org/Fedimins/mastodon-maintenance-tasks) © 2023 by [Tealk](https://forum.fedimins.net/u/Tealk) is licensed under [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/?ref=chooser-v1)
