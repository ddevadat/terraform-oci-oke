# Copyright (c) 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "null_resource" "create_helmfile_dir" {
  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.operator_host
    user                = var.operator_user
    private_key         = var.ssh_private_key
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.yaml_manifest_path}/helmfile"
    ]
  }

}

resource "null_resource" "upload_inline_helmfile" {
  count      = var.custom_app_helmfile_values != "" ? 1 : 0
  depends_on = [null_resource.create_helmfile_dir]

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.operator_host
    user                = var.operator_user
    private_key         = var.ssh_private_key
  }

  provisioner "file" {
    content     = var.custom_app_helmfile_values
    destination = "${local.yaml_manifest_path}/helmfile/cilium-helmfile.yaml"
  }
}

resource "null_resource" "upload_helmfile_files" {
  for_each   = { for file in var.custom_app_helmfile_values_files : file => file }
  depends_on = [null_resource.create_helmfile_dir]

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.operator_host
    user                = var.operator_user
    private_key         = var.ssh_private_key
  }

  provisioner "file" {
    source      = each.value
    destination = "${local.yaml_manifest_path}/helmfile/${basename(each.value)}"
  }

  triggers = {
    file_path = each.value
  }
}

resource "null_resource" "helmfile_apply" {
  depends_on = [
    null_resource.upload_inline_helmfile,
    null_resource.upload_helmfile_files
  ]

  provisioner "remote-exec" {
    inline = [
      "cd ${local.yaml_manifest_path}/helmfile",
      "for file in *.yaml; do echo \"Applying $file\"; helmfile -f $file apply; done"
    ]
  }

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.operator_host
    user                = var.operator_user
    private_key         = var.ssh_private_key
  }
}
