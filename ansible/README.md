# These ansible scripts are used to update the configs on the k3s nodes

## Usage

Update single node:

```shell
ansible-playbook -l rpi31.faircloth.ca playbook.yaml --ask-vault-pass
```

Update all nodes:

```shell
ansible-playbook playbook.yaml --ask-vault-pass
```

## Additional k8s manifests

To install any additional k8s manifests, just put them in the `k8s/` directory and run the `provision.yaml` file (with the above command).
