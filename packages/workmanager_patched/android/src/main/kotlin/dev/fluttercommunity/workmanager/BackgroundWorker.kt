package dev.fluttercommunity.workmanager

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject

/**
 * Worker that bridges the Android WorkManager job to the Dart callback.
 */
class BackgroundWorker(appContext: Context, workerParams: WorkerParameters) :
  Worker(appContext, workerParams) {

  override fun doWork(): Result {
    val taskName = inputData.getString(WorkmanagerPlugin.KEY_TASK_NAME) ?: return Result.failure()
    val rawInput = inputData.getString(WorkmanagerPlugin.KEY_INPUT_DATA)
    val payload = rawInput?.let { decodeJson(it) }
    return try {
      val success = WorkmanagerPlugin.executeTask(applicationContext, taskName, payload)
      if (success) Result.success() else Result.retry()
    } catch (error: Exception) {
      Result.retry()
    }
  }

  private fun decodeJson(raw: String): Map<String, Any?>? {
    return try {
      val json = JSONObject(raw)
      json.toMap()
    } catch (_: Exception) {
      null
    }
  }

  private fun JSONObject.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val iterator = keys()
    while (iterator.hasNext()) {
      val key = iterator.next()
      val value = get(key)
      map[key] = when (value) {
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        JSONObject.NULL -> null
        else -> value
      }
    }
    return map
  }

  private fun JSONArray.toList(): List<Any?> {
    val list = mutableListOf<Any?>()
    for (index in 0 until length()) {
      val value = get(index)
      list.add(
        when (value) {
          is JSONObject -> value.toMap()
          is JSONArray -> value.toList()
          JSONObject.NULL -> null
          else -> value
        }
      )
    }
    return list
  }
}
