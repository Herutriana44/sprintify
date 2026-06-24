import 'dart:async';
import 'dart:isolate';

/// Generic isolate worker untuk task parallel processing.
class IsolateWorker<I, O> {
  IsolateWorker({
    required this.id,
    required this.entryPoint,
  });

  final int id;
  final void Function(SendPort) entryPoint;

  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<O>> _pendingTasks = {};
  int _nextTaskId = 0;
  bool _ready = false;
  int _activeTasks = 0;

  Future<void> start() async {
    _isolate = await Isolate.spawn(entryPoint, _receivePort.sendPort);
    final completer = Completer<void>();

    _receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        _ready = true;
        completer.complete();
      } else if (message is _IsolateResponse<O>) {
        _activeTasks--;
        _pendingTasks.remove(message.taskId)?.complete(message.result);
      } else if (message is _IsolateError) {
        _activeTasks--;
        _pendingTasks.remove(message.taskId)?.completeError(message.error);
      }
    });

    return completer.future;
  }

  Future<O> execute(I input) {
    if (!_ready) {
      return Future.error('Worker not ready');
    }

    final taskId = _nextTaskId++;
    final completer = Completer<O>();
    _pendingTasks[taskId] = completer;
    _activeTasks++;

    _sendPort!.send(_IsolateTask<I>(taskId: taskId, input: input));
    return completer.future;
  }

  bool get isReady => _ready;
  bool get isBusy => _activeTasks > 0;
  int get activeTaskCount => _activeTasks;

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
    _ready = false;
    for (final completer in _pendingTasks.values) {
      if (!completer.isCompleted) {
        completer.completeError('Worker disposed');
      }
    }
    _pendingTasks.clear();
  }
}

/// Pool dari multiple isolate workers untuk load balancing.
class IsolatePool<I, O> {
  IsolatePool({
    required this.workerEntryPoint,
    this.poolSize = 4,
  });

  final void Function(SendPort) workerEntryPoint;
  final int poolSize;

  final List<IsolateWorker<I, O>> _workers = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final futures = <Future<void>>[];
    for (int i = 0; i < poolSize; i++) {
      final worker = IsolateWorker<I, O>(
        id: i,
        entryPoint: workerEntryPoint,
      );
      _workers.add(worker);
      futures.add(worker.start());
    }

    await Future.wait(futures);
    _initialized = true;
  }

  /// Execute task di worker yang paling tidak sibuk.
  Future<O> execute(I input) async {
    if (!_initialized) {
      throw StateError('Pool not initialized');
    }

    // Load balancing: pilih worker dengan active task paling sedikit
    IsolateWorker<I, O>? leastBusyWorker;
    int minActiveTasks = double.maxFinite.toInt();

    for (final worker in _workers) {
      if (worker.isReady && worker.activeTaskCount < minActiveTasks) {
        leastBusyWorker = worker;
        minActiveTasks = worker.activeTaskCount;
      }
    }

    if (leastBusyWorker == null) {
      throw StateError('No available workers');
    }

    return leastBusyWorker.execute(input);
  }

  /// Execute multiple tasks secara parallel di pool.
  Future<List<O>> executeAll(List<I> inputs) async {
    return Future.wait(inputs.map((input) => execute(input)));
  }

  /// Execute tasks dalam batch dengan size maksimal per batch.
  Stream<O> executeBatch(List<I> inputs, {int batchSize = 10}) async* {
    for (int i = 0; i < inputs.length; i += batchSize) {
      final end = (i + batchSize < inputs.length) ? i + batchSize : inputs.length;
      final batch = inputs.sublist(i, end);
      final results = await executeAll(batch);
      for (final result in results) {
        yield result;
      }
    }
  }

  bool get isInitialized => _initialized;
  int get workerCount => _workers.length;

  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _initialized = false;
  }
}

// ---------------------------------------------------------------------------
// Internal message types
// ---------------------------------------------------------------------------

class _IsolateTask<I> {
  _IsolateTask({required this.taskId, required this.input});
  final int taskId;
  final I input;
}

class _IsolateResponse<O> {
  _IsolateResponse({required this.taskId, required this.result});
  final int taskId;
  final O result;
}

class _IsolateError {
  _IsolateError({required this.taskId, required this.error});
  final int taskId;
  final Object error;
}
