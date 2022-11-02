# Manual upgrade

If you do not install any upgrade for around 6-12 months or longer, it can happen that your instance is so outdated that in the meantime the PHP version of the MiniMailboxes container got bumped to a version that is not compatible with your currently installed MiniMailboxes version which means that after doing an upgrade after this long time, MiniMailboxes will suddenly not work anymore. There is unfortunately no way to fix this from the maintainer side if you refrain from upgrading for so long.

The only way to fix this on your side is upgrading regularly (e.g. by enabling daily backups which will also automatically upgrade all containers) and following the steps below:

1. Start all containers from the aio interface (now, it will report that MiniMailboxes is restarting because it is not able to start due to the above mentioned problem)
1. Do **not** click on `Stop containers` because you will need them running going forward, see below
1. Stop the MiniMailboxes container and the Apache container by running `sudo docker stop minimailboxes-aio-minimailboxes && sudo docker stop minimailboxes-aio-apache`.
1. Find out with which PHP version your installed MiniMailboxes is compatible by running `sudo cat /var/lib/docker/volumes/minimailboxes_aio_minimailboxes/_data/lib/versioncheck.php`. (There you will find information about the max. supported PHP version.)
1. Run the following commands in order to reverse engineer the MiniMailboxes container:
    ```bash
        sudo docker pull assaflavie/runlike
        echo '#/bin/bash' > /tmp/minimailboxes-aio-minimailboxes
        sudo docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike -p minimailboxes-aio-minimailboxes >> /tmp/minimailboxes-aio-minimailboxes
        sudo chown root:root /tmp/minimailboxes-aio-minimailboxes
    ```
1. Now open the file with e.g. nano: `sudo nano /tmp/minimailboxes-aio-minimailboxes` and change the line that should probably be `minimailboxes/aio-minimailboxes:latest` on x64 or `minimailboxes/aio-minimailboxes:latest-arm64` on arm64 to the highest compatible PHP version: E.g. `minimailboxes/aio-minimailboxes:php8.0-latest` on x64 or `minimailboxes/aio-minimailboxes:php8.0-latest-arm64` on arm64. Then save the file and close it with `[Ctrl]+[o]` -> `[Enter]` and `[Ctrl]+[x]`.
1. After doing so, remove the MiniMailboxes container with `sudo docker rm minimailboxes-aio-minimailboxes`.
1. Now start the MiniMailboxes container with the new tag by simply running `sudo bash /tmp/minimailboxes-aio-minimailboxes` which at startup should automatically upgrade MiniMailboxes to a more recent version. If not, make sure that there is no `skip.update` file in the MiniMailboxes datadir. If there is such a file, simply delete the file and restart the container again.<br>
**Info**: You can open the MiniMailboxes container logs with `sudo docker logs -f minimailboxes-aio-minimailboxes`.
1. After the MiniMailboxes container is started (you can tell by looking at the logs), simply restart the container again with `sudo docker restart minimailboxes-aio-minimailboxes` until it does not install a new MiniMailboxes update anymore upon the container startup.
1. Now, you should be able to use the AIO interface again by simply stopping the AIO containers and starting them again which should finally bring up your instance again.
1. If not and if you get the same error again, you may repeat the process starting from the beginning again until your MiniMailboxes version is finally up-to-date.
1. Now, if everything is finally running as usual again, it is recommended to create a backup in order to save the current state. Also you should think about enabling daily backups if doing regularl upgrades is too much effort for you.
