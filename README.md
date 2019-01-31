# mkgc
Create VMs on GoogleCloudPlatform and configure them with one command.

# Usage

Edit setting.sh file as you want, and execute mkgc command.

```shell
./format setting.sh
./mkgc <name>
```

Configure SSH client by editing /etc/ssh/ssh_conf.

```:/etc/ssh/ssh_conf
# optional
PasswordAuthentication no

# mandatory
GSSAuthentication yes
```

Set domain search in /etc/resolv.conf.

```:/etc/resolv.conf
search main.gc
```

Now you can access to the vm you create with SSH.

```shell
ssh <name>
```

# Explanation
<dl>
  <dt>format</dt>
  <dd>Replace a series of 4 spaces with a tab.</dd>
  
  <dt>mkgc</dt>
  <dd>Requese GCP to create a vm with gcloud.</dt>
</dl>
