enum BleProvisioningState {
  idle,
  sendingCredentials,
  connectingToWifi,
  checkingStatus,
  registeringDevice,
  success,
  failed,
}

class ProvisioningProgress {
  final BleProvisioningState state;
  final String? error;

  const ProvisioningProgress(this.state, {this.error});
}
