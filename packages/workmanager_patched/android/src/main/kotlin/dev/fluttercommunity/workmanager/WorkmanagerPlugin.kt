package dev.fluttercommunity.workmanager

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.FlutterCallbackInformation
import java.util.HashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONArray
import org.json.JSONObject

/**
 * Implementation of the Workmanager plugin that targets the Flutter v2 Android embedding.
 */
class WorkmanagerPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, FOREGROUND_CHANNEL)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> handleInitialize(call, result)
      "registerOneOffTask" -> handleRegisterOneOff(call, result)
      "registerPeriodicTask" -> handleRegisterPeriodic(call, result)
      "cancelAll" -> {
        WorkManager.getInstance(context).cancelAllWork()
        result.success(null)
      }
      "cancelByUniqueName" -> {
        val name = call.arguments as? String
        if (name == null) {
          result.error("argument_error", "Unique name is required", null)
        } else {
          WorkManager.getInstance(context).cancelUniqueWork(name)
          result.success(null)
        }
      }
      "cancelByTag" -> {
        val tag = call.arguments as? String
        if (tag == null) {
          result.error("argument_error", "Tag is required", null)
        } else {
          WorkManager.getInstance(context).cancelAllWorkByTag(tag)
          result.success(null)
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun handleInitialize(call: MethodCall, result: Result) {
    val dispatcherHandle = (call.argument<Number>("dispatcherHandle")?.toLong())
    if (dispatcherHandle == null || dispatcherHandle == 0L) {
      result.error("argument_error", "dispatcherHandle is required", null)
      return
    }
    val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    preferences.edit()
      .putLong(KEY_CALLBACK_HANDLE, dispatcherHandle)
      .putBoolean(KEY_DEBUG_MODE, call.argument<Boolean>("isInDebugMode") ?: false)
      .apply()
    result.success(true)
  }

  private fun handleRegisterOneOff(call: MethodCall, result: Result) {
    val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
    val uniqueName = args["uniqueName"] as? String
    val taskName = args["taskName"] as? String
    if (uniqueName.isNullOrEmpty() || taskName.isNullOrEmpty()) {
      result.error("argument_error", "uniqueName and taskName are required", null)
      return
    }
    val dataBuilder = androidx.work.Data.Builder()
    dataBuilder.putString(KEY_TASK_NAME, taskName)
    val inputData = args["inputData"]
    if (inputData != null) {
      dataBuilder.putString(KEY_INPUT_DATA, serializeInputData(inputData))
    }

    val builder = OneTimeWorkRequestBuilder<BackgroundWorker>()
      .setInputData(dataBuilder.build())

    parseConstraints(args["constraints"])?.let { builder.setConstraints(it) }
    val delay = (args["initialDelayMillis"] as? Number)?.toLong()
    if (delay != null && delay > 0) {
      builder.setInitialDelay(delay, TimeUnit.MILLISECONDS)
    }

    parseBackoffPolicy(args["backoffPolicy"])?.let { (policy, duration) ->
      builder.setBackoffCriteria(policy, duration, TimeUnit.MILLISECONDS)
    }

    (args["tags"] as? List<*>)
      ?.mapNotNull { it as? String }
      ?.forEach { builder.addTag(it) }

    val work = builder.build()
    val existingPolicy = parseExistingWorkPolicy(args["existingWorkPolicy"])
    WorkManager.getInstance(context).enqueueUniqueWork(uniqueName, existingPolicy, work)
    result.success(true)
  }

  private fun handleRegisterPeriodic(call: MethodCall, result: Result) {
    val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
    val uniqueName = args["uniqueName"] as? String
    val taskName = args["taskName"] as? String
    val frequencyMillis = (args["frequencyMillis"] as? Number)?.toLong()
    if (uniqueName.isNullOrEmpty() || taskName.isNullOrEmpty() || frequencyMillis == null) {
      result.error("argument_error", "uniqueName, taskName and frequency are required", null)
      return
    }

    val dataBuilder = androidx.work.Data.Builder()
    dataBuilder.putString(KEY_TASK_NAME, taskName)
    val inputData = args["inputData"]
    if (inputData != null) {
      dataBuilder.putString(KEY_INPUT_DATA, serializeInputData(inputData))
    }

    val period = frequencyMillis.coerceAtLeast(MIN_PERIODIC_INTERVAL_MILLIS)
    val builder = PeriodicWorkRequestBuilder<BackgroundWorker>(
      period,
      TimeUnit.MILLISECONDS
    ).setInputData(dataBuilder.build())

    parseConstraints(args["constraints"])?.let { builder.setConstraints(it) }

    val initialDelay = (args["initialDelayMillis"] as? Number)?.toLong()
    if (initialDelay != null && initialDelay > 0) {
      builder.setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
    }

    parseBackoffPolicy(args["backoffPolicy"])?.let { (policy, duration) ->
      builder.setBackoffCriteria(policy, duration, TimeUnit.MILLISECONDS)
    }

    (args["tags"] as? List<*>)
      ?.mapNotNull { it as? String }
      ?.forEach { builder.addTag(it) }

    val work = builder.build()
    val existingPolicy = parseExistingPeriodicPolicy(args["existingWorkPolicy"])
    WorkManager.getInstance(context).enqueueUniquePeriodicWork(uniqueName, existingPolicy, work)
    result.success(true)
  }

  companion object {
    private const val FOREGROUND_CHANNEL = "plugins.flutter.io/workmanager"
    private const val BACKGROUND_CHANNEL = "plugins.flutter.io/workmanager_background"
    private const val PREFS = "dev.fluttercommunity.workmanager.preferences"
    private const val KEY_CALLBACK_HANDLE = "callback_dispatcher_handle"
    private const val KEY_DEBUG_MODE = "debug_mode"
    internal const val KEY_TASK_NAME = "workmanager_task_name"
    internal const val KEY_INPUT_DATA = "workmanager_input_data"
    private const val MIN_PERIODIC_INTERVAL_MILLIS = 15L * 60L * 1000L

    @Volatile private var backgroundEngine: FlutterEngine? = null
    @Volatile private var backgroundChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun getDispatcherHandle(context: Context): Long? {
      val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val handle = preferences.getLong(KEY_CALLBACK_HANDLE, 0L)
      return if (handle == 0L) null else handle
    }

    fun isInDebugMode(context: Context): Boolean {
      val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      return preferences.getBoolean(KEY_DEBUG_MODE, false)
    }

    @Synchronized
    fun ensureBackgroundIsolate(context: Context) {
      if (backgroundEngine != null) {
        return
      }
      val dispatcherHandle = getDispatcherHandle(context)
        ?: throw IllegalStateException("Workmanager is not initialized. Call initialize before scheduling tasks.")
      val callbackInfo: FlutterCallbackInformation = FlutterCallbackInformation.lookupCallbackInformation(dispatcherHandle)
        ?: throw IllegalStateException("Failed to retrieve callback information for handle $dispatcherHandle")

      val loader = FlutterInjector.instance().flutterLoader()
      if (!loader.initialized()) {
        loader.startInitialization(context)
      }
      loader.ensureInitializationComplete(context, null)

      val engine = FlutterEngine(context.applicationContext)
      val executor: DartExecutor = engine.dartExecutor
      val dartCallback = DartExecutor.DartCallback(
        context.assets,
        loader.findAppBundlePath(),
        callbackInfo
      )
      executor.executeDartCallback(dartCallback)

      backgroundChannel = MethodChannel(executor.binaryMessenger, BACKGROUND_CHANNEL)
      backgroundEngine = engine
    }

    fun executeTask(context: Context, taskName: String, inputData: Map<String, Any?>?): Boolean {
      ensureBackgroundIsolate(context)
      val latch = CountDownLatch(1)
      val success = AtomicBoolean(false)
      val arguments = HashMap<String, Any?>(2)
      arguments["taskName"] = taskName
      if (inputData != null) {
        arguments["inputData"] = inputData
      }

      val channel = backgroundChannel
        ?: throw IllegalStateException("Background channel is not initialized")

      mainHandler.post {
        channel.invokeMethod(
          "performTask",
          arguments,
          object : MethodChannel.Result {
            override fun success(result: Any?) {
              success.set((result as? Boolean) == true)
              latch.countDown()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
              success.set(false)
              latch.countDown()
            }

            override fun notImplemented() {
              success.set(false)
              latch.countDown()
            }
          }
        )
      }

      latch.await(10, TimeUnit.MINUTES)
      return success.get()
    }

    private fun serializeInputData(data: Any): String {
      return when (data) {
        is Map<*, *> -> JSONObject(data).toString()
        is Iterable<*> -> JSONArray().apply {
          data.forEach { put(it) }
        }.toString()
        else -> data.toString()
      }
    }

    private fun parseConstraints(raw: Any?): Constraints? {
      if (raw !is Map<*, *>) return null
      val builder = Constraints.Builder()
      (raw["requiresCharging"] as? Boolean)?.let { builder.setRequiresCharging(it) }
      (raw["requiresDeviceIdle"] as? Boolean)?.let { builder.setRequiresDeviceIdle(it) }
      (raw["requiresBatteryNotLow"] as? Boolean)?.let { builder.setRequiresBatteryNotLow(it) }
      (raw["requiresStorageNotLow"] as? Boolean)?.let { builder.setRequiresStorageNotLow(it) }
      when (raw["networkType"] as? String) {
        "connected" -> builder.setRequiredNetworkType(NetworkType.CONNECTED)
        "unmetered" -> builder.setRequiredNetworkType(NetworkType.UNMETERED)
        "notRoaming" -> builder.setRequiredNetworkType(NetworkType.NOT_ROAMING)
        "metered" -> builder.setRequiredNetworkType(NetworkType.METERED)
        "notRequired", null -> builder.setRequiredNetworkType(NetworkType.NOT_REQUIRED)
      }
      return builder.build()
    }

    private fun parseBackoffPolicy(raw: Any?): Pair<BackoffPolicy, Long>? {
      if (raw !is Map<*, *>) return null
      val policy = when (raw["policy"] as? String) {
        "linear" -> BackoffPolicy.LINEAR
        else -> BackoffPolicy.EXPONENTIAL
      }
      val delay = (raw["delayMillis"] as? Number)?.toLong() ?: return null
      return policy to delay
    }

    private fun parseExistingWorkPolicy(raw: Any?): ExistingWorkPolicy {
      return when (raw as? String) {
        "replace" -> ExistingWorkPolicy.REPLACE
        "append" -> ExistingWorkPolicy.APPEND
        else -> ExistingWorkPolicy.KEEP
      }
    }

    private fun parseExistingPeriodicPolicy(raw: Any?): ExistingPeriodicWorkPolicy {
      return when (raw as? String) {
        "replace" -> ExistingPeriodicWorkPolicy.REPLACE
        else -> ExistingPeriodicWorkPolicy.KEEP
      }
    }
  }
}
