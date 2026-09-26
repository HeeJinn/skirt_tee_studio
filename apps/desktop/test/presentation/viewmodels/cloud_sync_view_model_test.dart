import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/cloud_sync_view_model.dart';

import '../../fakes/fake_cloud_sync_repository.dart';

void main() {
  late FakeCloudSyncRepository repository;
  late CloudSyncViewModel viewModel;
  late int reloads;

  setUp(() async {
    repository = FakeCloudSyncRepository();
    reloads = 0;
    viewModel = CloudSyncViewModel(repository, onRemoteChanges: () async => reloads++);
    await viewModel.load();
  });

  test('a good sign-in connects', () async {
    final error = await viewModel.signIn('owner@example.com', FakeCloudSyncRepository.goodPassword);

    expect(error, isNull);
    expect(viewModel.state.status, CloudStatus.upToDate);
    expect(viewModel.state.email, 'owner@example.com');
    expect(viewModel.busy, isFalse);
  });

  test('a refused sign-in returns the message to show and stays disconnected', () async {
    final error = await viewModel.signIn('owner@example.com', 'wrong');

    expect(error, 'That email and password don\'t match.');
    expect(viewModel.state.status, CloudStatus.signedOut);
    expect(viewModel.busy, isFalse);
  });

  test('new data from the cloud reloads the screens', () async {
    repository.sendRemoteChanges();
    await pumpEventQueue();

    expect(reloads, 1);
  });

  test('status changes notify listeners', () async {
    var notified = 0;
    viewModel.addListener(() => notified++);

    repository.emit(const CloudSyncState(status: CloudStatus.offline, pendingChanges: 3));
    await pumpEventQueue();

    expect(notified, 1);
    expect(viewModel.state.pendingChanges, 3);
  });
}
