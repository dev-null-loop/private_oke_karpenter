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


## Prerequisites

Before installing OCI Karpenter in this stack, make sure the following are true:

- OKE cluster version is `>= v1.31`.
- The cluster already has bootstrap worker capacity so the KPO controller can run before Karpenter provisions new nodes.
- If the cluster uses OCI VCN-native pod networking, set `ociVcnIpNative: true` in the KPO values and use a compatible OciIpNativeCNI add-on version.
- The bastion host or another machine with private network reachability can access the private OKE API endpoint.
- Helm is available on the bastion (the provided bastion bootstrap path installs it).
- KPO IAM policies are created before the Helm install.

## Required IAM Policies

KPO runs in-cluster and uses OCI workload identity. The KPO controller service account must be allowed to manage OCI resources needed for node provisioning.

Typical policy shape:

```text
Allow any-user to <verb> <resource> in <location> where all {
  request.principal.type = 'workload',
  request.principal.namespace = '<karpenter-namespace>',
  request.principal.service_account = '<karpenter-service-account>',
  request.principal.cluster_id = '<oke-cluster-ocid>'
}
```

For this stack, the default namespace/service account are typically:
- namespace: `karpenter`
- service account: `karpenter`

Minimum controller policies:

```text
Allow any-user to manage instance-family in compartment <compartment-name> where all { ... }
Allow any-user to manage volumes in compartment <compartment-name> where all { ... }
Allow any-user to manage volume-attachments in compartment <compartment-name> where all { ... }
Allow any-user to manage virtual-network-family in compartment <compartment-name> where all { ... }
Allow any-user to inspect compartments in compartment <compartment-name> where all { ... }
```

Optional policies if you enable the related features in `OCINodeClass`:

```text
Allow any-user to use compute-capacity-reservations in compartment <compartment-name> where all { ... }
Allow any-user to use compute-clusters in compartment <compartment-name> where all { ... }
Allow any-user to use cluster-placement-groups in compartment <compartment-name> where all { ... }
Allow any-user to use tag-namespaces in compartment <compartment-name> where all { ... }
```

## Node Registration Policy

Instances launched by KPO also need permission to join the OKE cluster.
Create a dynamic group that matches the compartment(s) where KPO will launch worker nodes, then allow `CLUSTER_JOIN`.

Example dynamic group rule:

```text
ALL {instance.compartment.id = '<node-compartment-ocid>'}
```

Example policy:

```text
Allow dynamic-group <domain-name>/<dynamic-group-name> to {CLUSTER_JOIN} in compartment <compartment-name>
```

## Networking Notes

- This repo is designed for private OKE clusters.
- KPO should be installed from the bastion or another host that can reach the private API endpoint.
- For issue #25 reproduction, use OCI VCN-native pod networking and expose the secondary-VNIC tuning knobs through the `karpenter` variables.
- For long-term KPO operation with secondary VNICs, separate node and pod subnets are usually safer than reusing the same subnet, because IP fragmentation can cause NativePodNetwork failures even when total free IP count looks high.

## Issue #25 Repro Note

The current default repro-oriented settings are intentionally capable of reproducing the issue-25 failure pattern:

- `oci_vcn_ip_native = true`
- `use_same_node_and_pod_subnet = true`
- `secondary_vnic_ip_count = 32`
- a relatively small shared node/pod subnet

In that mode, OCI Karpenter can successfully launch instances and create `NodeClaim` objects, but the nodes may still fail to register if OCI Native Pod Network cannot allocate a contiguous IPv4 flexible CIDR block for pod IPs.

The key live signal is usually:

```text
CreatePrivateIPFailed
Unable to create IPv4 Flexible Cidr: Not enough capacity for allocating cidr of length 27
```

This means the stack is reproducing the same class of problem as GitHub issue #25: aggregate free IP count may still exist, but the subnet does not have enough contiguous address space for the requested secondary-VNIC pod allocation.

## Files

- `karpenter.tf`: rendered file outputs and helper commands
- `karpenter.variables.tf`: operator and repro settings
- `karpenter.auto.tfvars.example`: example Karpenter settings
- `karpenter/*.tftpl`: rendered KPO values, `OCINodeClass`, `NodePool`, repro workload, and debug script

## Important notes

- Keep one bootstrap node pool in Terraform. KPO should not bootstrap itself from zero.
- If you use OCI VCN-native pod networking, set `ociVcnIpNative=true` in the KPO values.
- For issue #25 reproduction, explicit secondary-VNIC configuration and pod-subnet control are the important knobs.
