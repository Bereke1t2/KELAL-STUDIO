import 'package:equatable/equatable.dart';

class Job extends Equatable {
  const Job({required this.id, required this.status, this.resultAssetId});

  final String id;
  final String status;
  final String? resultAssetId;

  @override
  List<Object?> get props => [id, status, resultAssetId];
}
