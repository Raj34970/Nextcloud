# Ansible Collection - lxhome.nextcloud

Documentation for the collection.

## Execution
``` shell
    ansible-playbook -i inventory.ini main.yml -t install
```

### debug

``` shell
    # To restore the data
    sudo docker exec -i mariadb mysql -u root -p"Nextcloud2024@%" nextcloud < backups/nextcloud-db_2025-04-08_22-43-12.sql

    # increase php memeroy size
    nano /usr/local/etc/php/php.ini-production
    # then find these ...
    php_value memory_limit 512M
    php_value upload_max_filesize 10G
    php_value post_max_size 10G
```