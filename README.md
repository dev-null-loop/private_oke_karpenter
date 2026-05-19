# private_oke_karpenter

Private OKE baseline plus OCI Karpenter (KPO) install and repro harness.

This repo is derived from `private_oke_oidc`, but scoped for:
- private OKE cluster creation
- bootstrap node pool creation
- bastion VM access path
- OCI Karpenter Helm install support
- generated `OCINodeClass` and `NodePool` manifests
- optional reproduction mode for Oracle KPO issue #25 (`NativePodNetwork` / secondary VNIC IP allocation failures)

## Flow

1. `terraform apply` builds the private OKE cluster, bootstrap node pool, bastion VM, and kubeconfig.
2. Terraform renders Karpenter files under `generated/`.
3. Use the bastion with the generated instance-principal kubeconfig to install KPO and apply the generated manifests.

## Files

- `karpenter.tf`: rendered file outputs and helper commands
- `karpenter.variables.tf`: operator and repro settings
- `karpenter.auto.tfvars.example`: example Karpenter settings
- `karpenter/*.tftpl`: rendered KPO values, `OCINodeClass`, `NodePool`, repro workload, and debug script

## Important notes

- Keep one bootstrap node pool in Terraform. KPO should not bootstrap itself from zero.
- If you use OCI VCN-native pod networking, set `ociVcnIpNative=true` in the KPO values.
- For issue #25 reproduction, explicit secondary-VNIC configuration and pod-subnet control are the important knobs.
