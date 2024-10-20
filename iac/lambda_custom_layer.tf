resource "aws_lambda_layer_version" "lambda_custom_layer" {
  filename                 = "${var.lambda_src_base}/common_layer/common_layer.zip"
  source_code_hash         = filebase64sha256("${var.lambda_src_base}/common_layer/common_layer.zip")
  layer_name               = "${var.app_name}-custom_lambda_layer-${var.stack_env}"
  compatible_runtimes      = ["python${var.python_version}"]
  compatible_architectures = [var.lambda_architectures]
  license_info             = "Private"
}
