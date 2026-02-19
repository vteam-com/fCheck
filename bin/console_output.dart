import 'dart:convert';
import 'dart:io';

import 'package:fcheck/src/models/app_strings.dart';
import 'package:fcheck/src/input_output/issue_location_utils.dart';
import 'package:fcheck/src/input_output/number_format_utils.dart';
import 'package:fcheck/src/analyzers/project_metrics.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_artifact.dart';
import 'package:fcheck/src/analyzers/code_size/code_size_outlier_utils.dart';
import 'package:fcheck/src/models/fcheck_config.dart';
import 'package:fcheck/src/models/ignore_config.dart';
import 'package:fcheck/src/models/project_type.dart';

import 'console_common.dart';

part 'console_output_report.dart';
part 'console_output_guides.dart';
part 'console_output_printers.dart';
part 'console_output_styles.dart';
