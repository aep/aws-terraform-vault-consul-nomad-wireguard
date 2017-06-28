cleaned copy of scn tf for publication.
removed all apps (nomad files) and most of the vault provisioning.

this may hopefully contain the full infrastructure eventually.


manual prep
================

- s3 bucket for tf state storage

- kms key for encrypting that storage

- route53 hosted zone: tf does not manage the zone, only the relevant records in it
  this is because we assume things get intermixed with manually launched services,
  such as the company website

- wild card tls cert for your domain in aws acm
  tf doesnt create this because it requires manual verification.
  Go to aws console -> certificate manager -> import or create a certificate


bring up tf cluster foundation
================================

    cd foundation
    terraform env new dev
    terraform apply

this will create a new vpc containing:

    - 1 border running
        - consul
        - wireguard
        - public ssh port
    - 3 cluster instances in an ASG running
        - consul
        - vault
        - nomad

setup vault
=========================================

    echo "Include $PWD/outputs/ssh_config" >> ~/.ssh/config
    ssh -L8500:consul:8500 -L4646:nomad:4646 -L8200:vault:8200 -L5000:registry:5000 border<DOMAIN>

open consul ui at http://localhost:8500
if it fails loading, wait for consul to settle.
it should have 3 failing vault services and everything else green.
now init vault

    sh output/vault-provisioner.sh

WRITE DOWN THE UNSEAL KEY
and probably the root token

    export VAULT_ADDR=http://localhost:8200
    vault auth <root token>
    vault mount aws


