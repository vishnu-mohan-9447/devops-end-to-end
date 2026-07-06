# Ansible - Jenkins host configuration

Installs Docker, Java, and Jenkins with required plugins on the EC2 host
provisioned by `terraform/test-dockercompose`. Jenkins console setup (admin
user, credentials, pipelines) is done manually after provisioning.

## Prerequisites on your laptop

```bash
python3 -m pip install --user ansible boto3 botocore
ansible-galaxy collection install -r requirements.yml
```

SSH access to the target host using the same key pair referenced by
`key_name` in `terraform/test-dockercompose/terraform.tfvars`.

## Run the playbook

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
```

## What gets configured

- **Docker**: Docker Engine + Compose plugin; `ubuntu` user added to the
  `docker` group.
- **Java**: OpenJDK 17 (required by current Jenkins LTS).
- **Jenkins**: installed from the official apt repo on port `8081` (8080
  is reserved for the frontend app).
- **Plugins**: installed from `roles/jenkins/files/plugins.txt` (git,
  pipeline, docker-workflow, sonar, github, blueocean, kubernetes-cli,
  etc.).

After the playbook finishes, open `http://<host>:8081`, enter the initial
admin password shown in the output, and finish setup in the Jenkins UI.

## Idempotency

Re-running the playbook is safe. Plugin installation is skipped once
`{{ jenkins_home }}/.plugins_provisioned` exists on the host.

## Troubleshooting

If a previous run failed after adding the Jenkins apt repo, the playbook
pre-tasks remove stale repo/key files before Docker runs `apt update`.

If apt still fails, SSH to the host and run:

```bash
sudo rm -f /etc/apt/sources.list.d/jenkins.list /usr/share/keyrings/jenkins-keyring.asc
sudo apt-get update
```

Then re-run the playbook.
