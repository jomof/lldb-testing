import lldb
import subprocess
import time
import argparse

_timestamp = int(time.time() * 100)


def run_debugging_session(serial, package):
    """
    Runs a debugging session using the LLDB Python API.

    Args:
        serial: The serial of the Android device to connect to.
    """
    # Create a new debugger instance.
    debugger = lldb.SBDebugger.Create()
    if not debugger:
        print('Error: Failed to create SBDebugger.')
        return

    # Tell the debugger to be in synchronous mode.
    # This means commands will block until they are finished.
    debugger.SetAsync(False)

    # Select and set the platform to 'remote-android'.
    # This is required for debugging on an Android device.
    platform = lldb.SBPlatform('remote-android')
    if not platform:
        print('Error: Failed to create remote-android platform.')
        return

    debugger.SetSelectedPlatform(platform)
    print('Platform set to remote-android')

    # Connect to the remote platform on the lldb-server.
    platform_connect_options = lldb.SBPlatformConnectOptions(
        f'unix-abstract-connect://[{serial}]/{package}-0/platform-{_timestamp}.sock')
    print(f'Connecting to URL: {platform_connect_options.GetURL()}')
    connect_error = platform.ConnectRemote(platform_connect_options)
    if connect_error.Fail():
        print(f'Error: Failed to connect to remote platform: {connect_error.GetCString()}')
        exit(1)
    print('Connected to remote platform successfully.')

    print('Listing pids on device...')
    error = lldb.SBError()
    processes = platform.GetAllProcesses(error)
    if error.Fail():
      print(f'Error listing process ids')
      exit(1)
    pid = 0
    for i in range(0, processes.GetSize()):
      info = lldb.SBProcessInfo()
      if processes.GetProcessInfoAtIndex(i, info) and info.GetName() in ['app_process64', 'app_process32', 'com.example.hellojni']:
          pid = info.GetProcessID()
          print(f'Match, process: {info.GetName()}')
      else:
        print(f'Not match, process: {info.GetName()}')
    if pid == 0:
      print('Failed to find matching pid')
      exit(1)
    print(f'Selected pid = {str(pid)}')

    # Attach to the process by its PID.
    error = lldb.SBError()
    target = debugger.CreateTarget(
        None,           # executable_file
        None,           # triple
        None,           # platform_name
        True,           # add_dependent_modules
        error           # error
    )
    if not error.Success():
      print(f"Error creating target: {error.GetCString()}")
      exit(1)

    print(f'Attaching to process {pid}...')
    attach_info = lldb.SBAttachInfo()
    attach_info.SetProcessID(pid)
    error = lldb.SBError()
    process = platform.Attach(attach_info, debugger, target, error)
    if not process or error.Fail():
        print(f'Error: Failed to attach to process with PID {pid}: {error.GetCString()}')
        return

    print(f'Attached to process with PID {process.GetProcessID()}')

    wait_for_stop(debugger.GetListener(), process, 10)

    print('Getting stack backtrace')
    debugger.HandleCommand('bt')

    # TODO:
    #print('Continuing process')
    #process.Continue()
    #print('Sleeping for 2 seconds')
    #time.sleep(2)
    #process.Stop()
    #wait_for_stop(debugger.GetListener(), process, 10)

    print('Test finished. Exiting.')

def wait_for_stop(listener, process, timeout_seconds):
  event = lldb.SBEvent()
  # Loop until the process is Running/Suspended or timeout.
  for i in range(timeout_seconds):
    listener.WaitForEvent(1, event) # Wait up to 1 second per loop iteration
    if event.IsValid() and lldb.SBProcess.EventIsProcessEvent(event):
      # We got a process event, check the state
      state_enum = process.GetState()
      print(f'Process state after waiting: {lldb.SBDebugger.StateAsCString(state_enum)}')
      if state_enum == lldb.eStateStopped:
        return
      time.sleep(1)
  print('Timed out while waiting for process to reach stopped state')
  exit(1)


def get_device_abis(serial):
  cmd = [
    'adb',
    '-s',
    serial,
    'shell',
    'getprop',
    'ro.product.cpu.abilist'
  ]
  result = subprocess.run(cmd, check=True, capture_output=True)
  out = result.stdout.decode('utf-8')
  abis = out.strip().split(',')
  return abis


def get_serial(android_abi):
  cmd = [
      'adb',
      'devices',
  ]
  result = subprocess.run(cmd, check=True, capture_output=True)
  out = result.stdout.decode('utf-8')
  devices = list(filter(str.strip, out.splitlines()[1:]))
  print(f'Devices found: {str(devices)}')
  if len(devices) == 0:
    print('No devices found!')
    exit(1)

  serial = None
  found = False
  for device in devices:
    parts = device.split()
    if len(parts) != 2:
      print(f'Failed to parse device line:\n{device}\nSkipping device.')
      continue

    serial, state = parts[0], parts[1]
    if state != 'device':
      continue

    # Compare the ABI of the device against what we are looking for.
    abis = get_device_abis(serial)
    print(f'Target ABI={android_abi} Device ABIs: {str(abis)}')
    if android_abi not in abis:
      print(f'Skipping device: Requested ABI={android_abi} not found in device ABIs={str(abis)}')
      continue

    found = True
    break

  if not found:
    print('No online devices found')
    exit(1)

  print(f'Using device serial = {serial}')
  return serial


def get_pid():
  return 1234


def build_testapp():
  """Builds the test app using gradlew."""
  print('Building test app...')
  cmd = ['./gradlew', 'assembleDebug']
  subprocess.run(cmd, cwd='testapp', check=True)


def install_apk(android_abi):
  """Uninstalls the previous version and installs the ABI-specific APK."""
  package = 'com.example.testapp'
  print(f'Uninstalling {package}...')
  subprocess.run(['adb', 'uninstall', package], check=False) # OK if not installed

  apk_path = f'testapp/app/build/outputs/apk/debug/app-{android_abi}-debug.apk'
  print(f'Installing APK: {apk_path}...')
  subprocess.run(['adb', 'install', '-r', apk_path], check=True)


def run_as(serial, package, cmd):
  new_cmd = [
      'adb',
      '-s',
      serial,
      'shell',
      'run-as',
      package
  ] + cmd
  print('Launching command: ' + str(cmd))
  return subprocess.Popen(new_cmd)

def launch_lldb_server(serial, package):
  print('Launching lldb-server on device...')
  cmd = [
      f'/data/data/{package}/lldb/bin/start_lldb_server.sh',
      f'/data/data/{package}/lldb',
      'unix-abstract',
      f'/{package}-0',
      f'platform-{_timestamp}.sock',
      '\'lldb process:gdb-remote packets\''
  ]
  process = run_as(serial, package, cmd)
  time.sleep(1)
  return process

def launch_app(serial, package, activity):
  print('Stopping and re-launching app...')
  cmd = [
      'adb',
      '-s',
      serial,
      'shell',
      'am',
      'force-stop',
      package
  ]
  subprocess.run(cmd, check=True)
  cmd = [
      'adb',
      '-s',
      serial,
      'shell',
      'am',
      'start',
      activity,
      '-a',
      'android.intent.action.MAIN',
      '-c',
      'android.intent.category.LAUNCHER'
  ]
  subprocess.run(cmd, check=True)

def push_file(serial, local_path, remote_path):
  cmd = [
      'adb',
      '-s',
      serial,
      'push',
      local_path,
      remote_path
  ]
  subprocess.run(cmd, check=True)


def push_lldb_server(serial, package, android_abi):
  print('Pushing lldb-server to device...')

  push_file(
      serial,
      f'build-{android_abi}/out/bin/lldb-server',
      '/data/local/tmp/')
  push_file(
      serial,
      'start_lldb_server.sh',
      '/data/local/tmp/')

  for subcmd in [
      'mkdir -p lldb/bin',
      'cp /data/local/tmp/lldb-server lldb/bin',
      'cp /data/local/tmp/start_lldb_server.sh lldb/bin/',
      'chmod +x lldb/bin/lldb-server',
      'chmod +x lldb/bin/start_lldb_server.sh',
  ]:
    return_code = run_as(serial, package, [subcmd]).wait()
    assert return_code == 0


def kill_lldb_server(serial, package):
  run_as(serial, package, ['pkill', '-9', 'lldb-server']).wait()

def main(args):
  serial = get_serial(args.android_abi)
  package = 'com.example.testapp'
  activity = f'{package}/.MainActivity'
  build_testapp()
  install_apk(args.android_abi)
  launch_app(serial, package, activity)
  kill_lldb_server(serial, package)
  push_lldb_server(serial, package, args.android_abi)
  process = launch_lldb_server(serial, package)
  try:
    print('This is where the debug session will start')
    run_debugging_session(serial, package)
    # time.sleep(1000)
  finally:
    print('Killing all lldb-server processes on device')
    kill_lldb_server(serial, package)

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument(
      "--android_abi",
      default="arm64-v8a",
      help="The ABI of the target Android device"
  )
  main(parser.parse_args())
