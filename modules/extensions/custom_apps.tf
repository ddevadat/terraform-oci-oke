# Copyright (c) 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  has_inline_helmfile     = var.custom_app_helmfile_values != ""
  has_file_helmfiles      = length(var.custom_app_helmfile_values_files) > 0
  invalid_helmfile_config = var.custom_app_install && !local.has_inline_helmfile && !local.has_file_helmfiles
  should_run_helmfile     = var.custom_app_install && (local.has_inline_helmfile || local.has_file_helmfiles)
}

resource "null_resource" "validate_custom_app_inputs" {
  count = local.invalid_helmfile_config ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: custom_app_helmfile_values or custom_app_helmfile_values_files must be provided when custom_app_install = true' && exit 1"
  }
}

resource "null_resource" "create_helmfile_dir" {

  count = local.should_run_helmfile ? 1 : 0

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
  count      = local.should_run_helmfile && local.has_inline_helmfile ? 1 : 0
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
    destination = "${local.yaml_manifest_path}/helmfile/custom-app-helmfile.yaml"
  }
}

# resource "null_resource" "upload_helmfile_files" {
#   for_each   = { for file in var.custom_app_helmfile_values_files : file => file }
#   depends_on = [null_resource.create_helmfile_dir]

#   connection {
#     bastion_host        = var.bastion_host
#     bastion_user        = var.bastion_user
#     bastion_private_key = var.ssh_private_key
#     host                = var.operator_host
#     user                = var.operator_user
#     private_key         = var.ssh_private_key
#   }

#   provisioner "file" {
#     source      = each.value
#     destination = "${local.yaml_manifest_path}/helmfile/${basename(each.value)}"
#   }

#   triggers = {
#     file_path = each.value
#   }
# }


resource "null_resource" "helmfile_apply" {
  count = local.should_run_helmfile ? 1 : 0

  depends_on = [
    null_resource.upload_inline_helmfile,
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
