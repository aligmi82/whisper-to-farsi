#!/usr/bin/env bash
set -euo pipefail

echo "==> project tree"
mkdir -p app/src/main/java/ir/livesub
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/assets/fonts

# ------------------------------------------------------------------ font
echo "==> Vazirmatn font"
FONT=app/src/main/assets/fonts/Vazirmatn-Medium.ttf
for u in \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/vazirmatn/Vazirmatn%5Bwght%5D.ttf" \
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/vazirmatn/Vazirmatn%5Bwght%5D.ttf" \
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/ttf/Vazirmatn-Medium.ttf" ; do
  if curl -fsSL "$u" -o "$FONT" 2>/dev/null && [ "$(stat -c%s "$FONT")" -gt 20000 ]; then
    echo "    font from $u"
    break
  fi
  rm -f "$FONT"
done
[ -f "$FONT" ] || echo "    !! font not downloaded, app falls back to sans-serif"

# ------------------------------------------------------------------ gradle
cat > settings.gradle.kts <<'EOF_SETTINGS'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "LiveSub"
include(":app")
EOF_SETTINGS

cat > build.gradle.kts <<'EOF_ROOT'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
EOF_ROOT

cat > gradle.properties <<'EOF_PROPS'
org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
kotlin.daemon.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
EOF_PROPS

# نسخهٔ Media3 با AGP 8.7.3 / Kotlin 2.0.21 سازگار است؛ پیش از build قطعی دوباره
# در https://developer.android.com/jetpack/androidx/releases/media3 چک شود.
cat > app/build.gradle.kts <<'EOF_APP'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "ir.livesub"
    compileSdk = 34

    defaultConfig {
        applicationId = "ir.livesub"
        minSdk = 29
        targetSdk = 34
        versionCode = 3
        versionName = "3.0"
    }

    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    packaging { resources.excludes += setOf("/META-INF/{AL2.0,LGPL2.1}") }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // استخراج صدا از فایل ویدیو/صوت ورودی: مستقیم با MediaExtractor/MediaCodec پلتفرم
    // (بند ۳.۲ سند مهاجرت). فقط media3-common لازم است، چون ChannelMixingAudioProcessor
    // و SonicAudioProcessor از همان پکیج استفاده می‌شوند؛ دیگر نیازی به media3-transformer
    // یا media3-effect (و در نتیجه Muxer داخلی آن‌ها) نیست — همان چیزی که خطای
    // «Muxer error» از آن می‌آمد.
    implementation("androidx.media3:media3-common:1.4.1")
}
EOF_APP

if [ -n "${ANDROID_HOME:-}" ]; then
  echo "sdk.dir=$ANDROID_HOME" > local.properties
fi

# ------------------------------------------------------------------ manifest + res
cat > app/src/main/AndroidManifest.xml <<'EOF_MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="false"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.LiveSub">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden|uiMode">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".ProcessingService"
            android:exported="false"
            android:foregroundServiceType="dataSync" />

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="ir.livesub.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
EOF_MANIFEST

cat > app/src/main/res/values/strings.xml <<'EOF_STRINGS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">زیرنویس‌ساز</string>
</resources>
EOF_STRINGS

cat > app/src/main/res/values/themes.xml <<'EOF_THEMES'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.LiveSub" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">#0F1013</item>
        <item name="android:statusBarColor">#0F1013</item>
        <item name="android:navigationBarColor">#0F1013</item>
    </style>
</resources>
EOF_THEMES

cat > app/src/main/res/drawable/ic_sub.xml <<'EOF_ICON'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M20,4H4C2.9,4 2,4.9 2,6v12c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2V6C22,4.9 21.1,4 20,4zM5,11h3v2H5V11zM14,17H5v-2h9V17zM19,17h-3v-2h3V17zM19,13h-9v-2h9V13z" />
</vector>
EOF_ICON

cat > app/src/main/res/xml/file_paths.xml <<'EOF_FILEPATHS'
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="work" path="livesub_work/" />
    <files-path name="outputs" path="outputs/" />
</paths>
EOF_FILEPATHS

# ------------------------------------------------------------------ Core.kt
cat > app/src/main/java/ir/livesub/Core.kt <<'EOF_CORE'
package ir.livesub

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Typeface
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.withContext
import okhttp3.ConnectionPool
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.TimeUnit

// ======================================================= وضعیت مشترک

/** حالت مشترک درون یک پروسه: سرویس پردازش می‌نویسد، رابط کاربری می‌خواند. */
object Bus {
    val running = MutableStateFlow(false)
    val stage = MutableStateFlow("")
    val progress = MutableStateFlow(0f)
    val lastError = MutableStateFlow<String?>(null)
    val resultPath = MutableStateFlow<String?>(null)
    val selectedName = MutableStateFlow<String?>(null)
    val uiTick = MutableStateFlow(0)
}

// ======================================================= تنظیمات

/**
 * فقط یک کلید و یک آدرس: هر دو مرحله روی گروک.
 * نام خانه‌های ذخیره‌سازی از نسخهٔ قبل عوض نشده تا کلید وارد‌شده از دست نرود.
 */
class Prefs(context: Context) {

    private val sp: SharedPreferences = try {
        val key = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context, "livesub_secure", key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (t: Throwable) {
        context.getSharedPreferences("livesub", Context.MODE_PRIVATE)
    }

    private fun s(k: String, d: String) = sp.getString(k, d) ?: d
    private fun w(k: String, v: String) { sp.edit().putString(k, v).apply() }

    var apiKey: String
        get() = s("stt_key", "")
        set(v) { w("stt_key", v) }

    var baseUrl: String
        get() {
            val v = s("stt_url", GROQ_URL)
            // آدرس دیپ‌سیک نسخهٔ قبل خودکار دور ریخته می‌شود
            return if (v.isBlank() || v.contains("deepseek")) GROQ_URL else v
        }
        set(v) { w("stt_url", v) }

    /** پیش‌فرض روی مدل دقیق‌تر، چون دیگر فشار تأخیر real-time نداریم (بند ۳.۴ سند). */
    var sttModel: String
        get() {
            val v = s("stt_model", STT_MODEL)
            return if (v.isBlank()) STT_MODEL else v
        }
        set(v) { w("stt_model", v) }

    var chatModel: String
        get() {
            val v = s("ds_model", CHAT_MODEL)
            return if (v.isBlank() || v.startsWith("deepseek")) CHAT_MODEL else v
        }
        set(v) { w("ds_model", v) }

    /** کد ISO زبان مبدأ. "auto" یعنی تشخیص خودکار که کندتر است. */
    var sourceLang: String
        get() = s("src_lang", "en")
        set(v) { w("src_lang", v) }

    companion object {
        const val GROQ_URL = "https://api.groq.com/openai/v1"
        const val STT_MODEL = "whisper-large-v3"
        const val CHAT_MODEL = "openai/gpt-oss-120b"
    }
}

// ======================================================= زبان‌ها

data class Lang(val code: String, val english: String, val fa: String)

val LANGS = listOf(
    Lang("en", "English", "انگلیسی"),
    Lang("ar", "Arabic", "عربی"),
    Lang("tr", "Turkish", "ترکی استانبولی"),
    Lang("ur", "Urdu", "اردو"),
    Lang("hi", "Hindi", "هندی"),
    Lang("es", "Spanish", "اسپانیایی"),
    Lang("fr", "French", "فرانسوی"),
    Lang("de", "German", "آلمانی"),
    Lang("it", "Italian", "ایتالیایی"),
    Lang("pt", "Portuguese", "پرتغالی"),
    Lang("ru", "Russian", "روسی"),
    Lang("uk", "Ukrainian", "اوکراینی"),
    Lang("nl", "Dutch", "هلندی"),
    Lang("sv", "Swedish", "سوئدی"),
    Lang("pl", "Polish", "لهستانی"),
    Lang("el", "Greek", "یونانی"),
    Lang("he", "Hebrew", "عبری"),
    Lang("ja", "Japanese", "ژاپنی"),
    Lang("ko", "Korean", "کره‌ای"),
    Lang("zh", "Chinese", "چینی"),
    Lang("th", "Thai", "تایلندی"),
    Lang("vi", "Vietnamese", "ویتنامی"),
    Lang("id", "Indonesian", "اندونزیایی"),
    Lang("auto", "the source language", "تشخیص خودکار (کندتر)"),
)

fun langOf(code: String): Lang = LANGS.firstOrNull { it.code == code } ?: LANGS[0]

// ======================================================= فونت

/** فونت وزیرمتن از assets، با بازگشت بی‌صدا به فونت پیش‌فرض اگر نبود. */
object VazirFont {

    private val CANDIDATES = listOf(
        "fonts/Vazirmatn-Medium.ttf",
        "fonts/Vazirmatn-Regular.ttf",
        "fonts/Vazir-Medium.ttf",
        "fonts/Vazir.ttf",
    )

    @Volatile private var cached: Typeface? = null

    @Volatile var loadedFromAssets: Boolean = false
        private set

    fun get(context: Context): Typeface {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            for (path in CANDIDATES) {
                val tf = runCatching { Typeface.createFromAsset(context.assets, path) }.getOrNull()
                if (tf != null) {
                    loadedFromAssets = true
                    cached = tf
                    return tf
                }
            }
            val fallback = Typeface.SANS_SERIF
            cached = fallback
            return fallback
        }
    }
}

// ======================================================= WAV

object WavEncoder {

    fun encode(pcm: ShortArray, length: Int, sampleRate: Int): ByteArray {
        val dataSize = length * 2
        val bb = ByteBuffer.allocate(44 + dataSize).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray(Charsets.US_ASCII))
        bb.putInt(36 + dataSize)
        bb.put("WAVE".toByteArray(Charsets.US_ASCII))
        bb.put("fmt ".toByteArray(Charsets.US_ASCII))
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(1)
        bb.putInt(sampleRate)
        bb.putInt(sampleRate * 2)
        bb.putShort(2)
        bb.putShort(16)
        bb.put("data".toByteArray(Charsets.US_ASCII))
        bb.putInt(dataSize)
        for (i in 0 until length) bb.putShort(pcm[i])
        return bb.array()
    }
}

// ======================================================= شبکه

object Net {

    private val pool = ConnectionPool(6, 5, TimeUnit.MINUTES)

    private fun base() = OkHttpClient.Builder()
        .connectionPool(pool)
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)

    /** رونویسی: تکه‌های صوتی می‌توانند چند مگابایت باشند، مهلت بلندتر لازم است. */
    val stt: OkHttpClient = base()
        .readTimeout(60, TimeUnit.SECONDS)
        .callTimeout(90, TimeUnit.SECONDS)
        .build()

    /** ترجمهٔ دسته‌ای غیر-استریمی: تا آمدن کل پاسخ صبر می‌کنیم. */
    val chat: OkHttpClient = base()
        .readTimeout(60, TimeUnit.SECONDS)
        .callTimeout(90, TimeUnit.SECONDS)
        .build()

    /** آزمایش دستی از داخل برنامه: کلید سالم است؟ مدل‌ها موجودند؟ */
    suspend fun checkKey(
        baseUrl: String,
        apiKey: String,
        sttModel: String,
        chatModel: String,
    ): String = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url(baseUrl.trimEnd('/') + "/models")
                .addHeader("Authorization", "Bearer " + apiKey)
                .build()
            stt.newCall(req).execute().use { r ->
                val body = r.body?.string().orEmpty()
                if (!r.isSuccessful) {
                    return@withContext "پذیرفته نشد (کد " + r.code + "): " + body.take(120)
                }
                val arr: JSONArray? = JSONObject(body).optJSONArray("data")
                val names = ArrayList<String>()
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        names.add(arr.optJSONObject(i)?.optString("id").orEmpty())
                    }
                }
                val a = if (names.contains(sttModel)) "موجود" else "پیدا نشد"
                val b = if (names.contains(chatModel)) "موجود" else "پیدا نشد"
                "کلید سالم است. مدل شنیدن: " + a + " — مدل ترجمه: " + b
            }
        } catch (t: Throwable) {
            "خطای شبکه: " + (t.message ?: "نامعلوم")
        }
    }
}

/** رونویسی با ویسپر روی گروک، خروجی segment‌دار برای ساخت SRT (بند ۳.۴ سند مهاجرت). */
class SttClient(private val http: OkHttpClient = Net.stt) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val language: String?,
    )

    data class RawSegment(val startSec: Double, val endSec: Double, val text: String)

    private class RateLimitedException(msg: String) : IOException(msg)

    /** در برخورد با کد ۴۲۹ با تأخیر تصاعدی دوباره تلاش می‌کند (بند ۳.۳ سند مهاجرت). */
    suspend fun transcribeChunk(wav: ByteArray, cfg: Config, prompt: String?): List<RawSegment> {
        var attempt = 0
        var delayMs = 2_000L
        while (true) {
            try {
                return doTranscribe(wav, cfg, prompt)
            } catch (rl: RateLimitedException) {
                attempt++
                if (attempt > MAX_RETRIES) throw rl
                delay(delayMs)
                delayMs = (delayMs * 2).coerceAtMost(60_000L)
            }
        }
    }

    private suspend fun doTranscribe(
        wav: ByteArray,
        cfg: Config,
        prompt: String?,
    ): List<RawSegment> = withContext(Dispatchers.IO) {
        val body = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", "chunk.wav", wav.toRequestBody(WAV))
            .addFormDataPart("model", cfg.model)
            .addFormDataPart("response_format", "verbose_json")
            .addFormDataPart("timestamp_granularities[]", "segment")
            .addFormDataPart("temperature", "0")
            .also { b ->
                if (!cfg.language.isNullOrBlank() && cfg.language != "auto") {
                    b.addFormDataPart("language", cfg.language)
                }
                // زمینه‌سازی اختیاری: اسم‌های خاص یا موضوع، از ورودی کاربر
                if (!prompt.isNullOrBlank()) b.addFormDataPart("prompt", prompt.take(220))
            }
            .build()

        val req = Request.Builder()
            .url(cfg.baseUrl.trimEnd('/') + "/audio/transcriptions")
            .addHeader("Authorization", "Bearer " + cfg.apiKey)
            .post(body)
            .build()

        http.newCall(req).execute().use { r ->
            val text = r.body?.string().orEmpty()
            if (r.code == 429) throw RateLimitedException(text.take(200))
            if (!r.isSuccessful) throw IOException("STT " + r.code + ": " + text.take(200))
            val json = JSONObject(text)
            val arr = json.optJSONArray("segments")
            if (arr == null) {
                return@use listOf(RawSegment(0.0, 0.0, json.optString("text").trim()))
            }
            val out = ArrayList<RawSegment>(arr.length())
            for (i in 0 until arr.length()) {
                val seg = arr.optJSONObject(i) ?: continue
                out.add(
                    RawSegment(
                        startSec = seg.optDouble("start", 0.0),
                        endSec = seg.optDouble("end", 0.0),
                        text = seg.optString("text").trim(),
                    )
                )
            }
            out
        }
    }

    private companion object {
        val WAV = "audio/wav".toMediaType()
        const val MAX_RETRIES = 5
    }
}

/** ترجمهٔ دسته‌ای غیر-استریمی؛ چند خط با شماره‌گذاری در یک درخواست (بند ۳.۶ سند مهاجرت). */
class BatchTranslator(private val http: OkHttpClient = Net.chat) {

    data class Config(
        val baseUrl: String,
        val apiKey: String,
        val model: String,
        val temperature: Double = 0.3,
    )

    suspend fun translateBatch(
        lines: List<String>,
        sourceLanguageEnglish: String,
        cfg: Config,
        contextTail: List<String> = emptyList(),
    ): List<String> = withContext(Dispatchers.IO) {
        if (lines.isEmpty()) return@withContext emptyList()

        val numbered = lines.mapIndexed { i, t -> (i + 1).toString() + ". " + t }.joinToString("\n")
        val contextBlock = if (contextTail.isNotEmpty()) {
            "Context from the immediately preceding lines (already translated; for pronoun/tone " +
                "continuity only, do not re-translate or re-number them):\n" +
                contextTail.takeLast(6).joinToString("\n") + "\n\n"
        } else ""

        val messages = JSONArray().apply {
            put(msg("system", systemPrompt(sourceLanguageEnglish)))
            put(msg("user", contextBlock + numbered))
        }
        val payload = JSONObject().apply {
            put("model", cfg.model)
            put("messages", messages)
            put("stream", false)
            put("temperature", cfg.temperature)
            put("max_tokens", 4000)
        }
        val req = Request.Builder()
            .url(cfg.baseUrl.trimEnd('/') + "/chat/completions")
            .addHeader("Authorization", "Bearer " + cfg.apiKey)
            .post(payload.toString().toRequestBody(JSON))
            .build()

        val raw = http.newCall(req).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw IOException("Chat " + resp.code + ": " + body.take(200))
            runCatching {
                JSONObject(body).getJSONArray("choices").getJSONObject(0)
                    .getJSONObject("message").optString("content")
            }.getOrDefault("")
        }
        parseNumbered(raw, lines.size)
    }

    private fun parseNumbered(raw: String, expected: Int): List<String> {
        val out = MutableList(expected) { "" }
        val re = Regex("(?m)^\\s*(\\d+)[.\\)]\\s*(.*)$")
        var matched = 0
        for (m in re.findAll(raw)) {
            val idx = m.groupValues[1].toIntOrNull() ?: continue
            if (idx in 1..expected) {
                out[idx - 1] = m.groupValues[2].trim()
                matched++
            }
        }
        if (matched < expected) {
            // اگر مدل شماره‌گذاری را کامل برنگرداند، بر اساس ترتیب خطوط غیرخالی پر می‌شود
            val fallback = raw.lines().map { it.trim() }.filter { it.isNotBlank() }
            for (i in out.indices) {
                if (out[i].isBlank() && i < fallback.size) out[i] = fallback[i]
            }
        }
        return out
    }

    private fun msg(role: String, content: String) =
        JSONObject().put("role", role).put("content", content)

    private fun systemPrompt(src: String) = "Translate each numbered line from " + src +
        " into natural, fluent written Persian — full idiomatic sentences, not a literal " +
        "word-for-word rendering. Preserve punctuation that signals tone (question marks, " +
        "exclamation marks, ellipses). Keep names and numbers. Use the provided context only " +
        "to keep pronouns, tone, and cross-sentence references consistent; never translate or " +
        "renumber the context lines themselves. Reply with the SAME numbering, one translated " +
        "line per number, nothing else — no preface, no notes. If a line has nothing " +
        "translatable, reply for that number with a single hyphen: -"

    private companion object {
        val JSON = "application/json; charset=utf-8".toMediaType()
    }
}

// ======================================================= پاک‌سازی متن

/** ویسپر روی موسیقی و سکوت جمله‌های خیالی می‌سازد؛ اینجا فیلتر می‌شوند. */
object TextClean {

    private val ARTIFACTS = setOf(
        "thank you", "thanks", "thanks for watching", "thank you very much",
        "bye", "okay", "ok", "you", "yeah", "hmm", "mm", "uh", "um", "so",
        "subtitles by the amara.org community", "amara.org", "the end",
        "please subscribe", "subscribe to my channel",
        "music", "applause", "silence", "laughter",
    )

    private val BRACKETED = Regex("^[\\[(].*[\\])]$")
    private val PUNCT_ONLY = Regex("^[\\p{Punct}\\s\u266A\u266B\u2026\u00B7\u2014\u2013\u200C]+$")
    private val THINK = Regex("(?s)<think>.*?</think>")

    fun normalize(s: String): String = s
        .replace(THINK, "")
        .replace('\n', ' ')
        .replace(Regex("\\s+"), " ")
        .trim()

    /**
     * فقط جمله‌های خیلی کوتاه و بی‌محتوا حذف می‌شوند. علائم نگارشی حفظ می‌شوند
     * (بند ۳.۴ سند مهاجرت) چون به مدل ترجمه سرنخ لحن می‌دهند.
     */
    fun isNoise(text: String, durationMs: Int): Boolean {
        if (text.isBlank()) return true
        if (PUNCT_ONLY.matches(text)) return true
        if (BRACKETED.matches(text)) return true
        val key = text.lowercase().trim().trimEnd('.', '!', '?', ',', '\u060C')
        return key in ARTIFACTS && durationMs < 2_000
    }

    fun collapseRepeats(s: String): String {
        val words = s.split(' ')
        if (words.size < 6) return s
        for (l in 1..6) {
            if (words.size < l * 3) continue
            val a = words.subList(words.size - l, words.size)
            val b = words.subList(words.size - 2 * l, words.size - l)
            val c = words.subList(words.size - 3 * l, words.size - 2 * l)
            if (a == b && b == c) {
                var end = words.size
                while (end - 2 * l >= 0 &&
                    words.subList(end - l, end) == words.subList(end - 2 * l, end - l)
                ) end -= l
                return words.subList(0, end).joinToString(" ")
            }
        }
        return s
    }

    /** پیام خطای خام سرویس را به یک جملهٔ کوتاه فارسی تبدیل می‌کند. */
    fun friendlyError(raw: String): String = when {
        raw.contains("401") || raw.contains("403") -> "کلید API پذیرفته نشد"
        raw.contains("402") || raw.contains("insufficient") -> "اعتبار حساب تمام شده"
        raw.contains("413") -> "حجم فایل ارسالی بیش از حد مجاز است"
        raw.contains("429") -> "سقف درخواست پر شد، کمی صبر کنید"
        raw.contains("decommission") || raw.contains("does not exist") -> "نام مدل معتبر نیست"
        raw.contains("timeout", true) || raw.contains("timed out", true) -> "اینترنت کند است"
        raw.contains("Unable to resolve host") || raw.contains("Failed to connect") ->
            "به سرویس وصل نشد"
        else -> raw.take(90)
    }
}
EOF_CORE

# ------------------------------------------------------------------ AudioExtractor.kt
cat > app/src/main/java/ir/livesub/AudioExtractor.kt <<'EOF_EXTRACTOR'
package ir.livesub

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.audio.SonicAudioProcessor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * استخراج صدای مونو ۱۶kHz از فایل ویدیو/صوت ورودی (بند ۳.۲ سند مهاجرت).
 *
 * نسخهٔ قبلی این کلاس از androidx.media3:media3-transformer برای export به یک فایل MP4
 * «دورریختنی» استفاده می‌کرد و هم‌زمان با یک AudioProcessor واسط، PCM را مستقیم در یک WAV
 * می‌نوشت. مشکل این بود که خروجی واقعی WAV بود ولی Transformer همچنان مجبور بود صدا را
 * برای همان فایل دورریختنی انکود/مالتی‌پلکس کند؛ روی برخی فایل‌های ورودی این مرحلهٔ
 * بی‌ربط با «Muxer error» (ExportException از InAppMp4Muxer داخلی Transformer) شکست
 * می‌خورد.
 *
 * این نسخه اصلاح‌شده اصلاً به Transformer/Muxer نیازی ندارد: مستقیماً با
 * android.media.MediaExtractor ترک صوتی فایل ورودی خوانده و با android.media.MediaCodec
 * دیکد می‌شود؛ downmix و resample همچنان با همان AudioProcessorهای رسمی Media3
 * (ChannelMixingAudioProcessor و SonicAudioProcessor، که در media3-common هستند و
 * نیازی به ماژول transformer ندارند) انجام می‌شود و نتیجه مستقیم در یک WAV مونو
 * ۱۶بیتی نوشته می‌شود. چون هیچ Muxer‌ای در مسیر نیست، آن کلاس خطا از ریشه حذف شده.
 */
object AudioExtractor {

    const val TARGET_SAMPLE_RATE = 16_000
    const val TARGET_CHANNELS = 1

    suspend fun extractMonoWav16k(context: Context, inputUri: Uri, outFile: File): File =
        withContext(Dispatchers.IO) {
            val extractor = MediaExtractor()
            var decoder: MediaCodec? = null
            var raf: RandomAccessFile? = null
            var success = false
            try {
                extractor.setDataSource(context, inputUri, null)

                var trackIndex = -1
                var trackFormat: MediaFormat? = null
                for (i in 0 until extractor.trackCount) {
                    val f = extractor.getTrackFormat(i)
                    val mime = f.getString(MediaFormat.KEY_MIME)
                    if (mime != null && mime.startsWith("audio/")) {
                        trackIndex = i
                        trackFormat = f
                        break
                    }
                }
                val fmt = trackFormat
                    ?: throw IllegalStateException("هیچ ترک صوتی در فایل ورودی پیدا نشد")
                extractor.selectTrack(trackIndex)

                val mime = fmt.getString(MediaFormat.KEY_MIME)!!
                val codec = MediaCodec.createDecoderByType(mime)
                codec.configure(fmt, null, null, 0)
                codec.start()
                decoder = codec

                val f = RandomAccessFile(outFile, "rw")
                f.setLength(0)
                f.write(ByteArray(44)) // جای هدر؛ در پایان با اندازهٔ واقعی جایگزین می‌شود
                raf = f

                // مقدار اولیه از فرمت ترک؛ اگر دیکودر در INFO_OUTPUT_FORMAT_CHANGED مقدار
                // دقیق‌تری بدهد (که معمولاً می‌دهد)، جایگزین می‌شود.
                var sampleRate = if (fmt.containsKey(MediaFormat.KEY_SAMPLE_RATE))
                    fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE) else TARGET_SAMPLE_RATE
                var channelCount = if (fmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT))
                    fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 1

                var downmix: ChannelMixingAudioProcessor? = null
                var resample: SonicAudioProcessor? = null
                var dataBytesWritten = 0L

                fun buildProcessors(rate: Int, channels: Int): Pair<ChannelMixingAudioProcessor, SonicAudioProcessor> {
                    val dm = ChannelMixingAudioProcessor().apply {
                        putChannelMixingMatrix(ChannelMixingMatrix.create(1, TARGET_CHANNELS))
                        putChannelMixingMatrix(ChannelMixingMatrix.create(2, TARGET_CHANNELS))
                        if (channels > 2) {
                            // پوشش فایل‌های چندکاناله (مثلاً ۵.۱)؛ به مونو خلاصه می‌شود
                            putChannelMixingMatrix(ChannelMixingMatrix.create(channels, TARGET_CHANNELS))
                        }
                    }
                    val sm = SonicAudioProcessor().apply {
                        setOutputSampleRateHz(TARGET_SAMPLE_RATE)
                    }
                    val inFormat = AudioProcessor.AudioFormat(rate, channels, C.ENCODING_PCM_16BIT)
                    val midFormat = dm.configure(inFormat)
                    sm.configure(midFormat)
                    dm.flush()
                    sm.flush()
                    return dm to sm
                }

                fun ensureProcessors() {
                    if (downmix == null) {
                        val (dm, sm) = buildProcessors(sampleRate, channelCount)
                        downmix = dm
                        resample = sm
                    }
                }

                // یک بافر ByteBuffer را کامل از یک AudioProcessor عبور می‌دهد و خروجی را
                // به‌صورت ByteBuffer تازه برمی‌گرداند (یا اگر processor غیرفعال بود، همان
                // ورودی بدون تغییر رد می‌شود).
                fun drain(processor: AudioProcessor, input: ByteBuffer, endOfStream: Boolean): ByteBuffer {
                    if (!processor.isActive) return input
                    if (input.hasRemaining()) processor.queueInput(input)
                    if (endOfStream) processor.queueEndOfStream()
                    val collected = ByteArrayOutputStream()
                    while (true) {
                        val out = processor.output
                        if (!out.hasRemaining()) break
                        val chunk = ByteArray(out.remaining())
                        out.get(chunk)
                        collected.write(chunk)
                    }
                    val bytes = collected.toByteArray()
                    return ByteBuffer.wrap(bytes).order(ByteOrder.nativeOrder())
                }

                fun writePcm(buf: ByteBuffer, endOfStream: Boolean) {
                    ensureProcessors()
                    val afterDownmix = drain(downmix!!, buf, endOfStream)
                    val afterResample = drain(resample!!, afterDownmix, endOfStream)
                    if (afterResample.hasRemaining()) {
                        val n = afterResample.remaining()
                        val bytes = ByteArray(n)
                        afterResample.get(bytes)
                        raf!!.write(bytes)
                        dataBytesWritten += n
                    }
                }

                val bufferInfo = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                val timeoutUs = 10_000L

                while (!outputDone) {
                    currentCoroutineContext().ensureActive()

                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(timeoutUs)
                        if (inIndex >= 0) {
                            val inBuf = codec.getInputBuffer(inIndex)!!
                            val sampleSize = extractor.readSampleData(inBuf, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(
                                    inIndex, 0, sampleSize, extractor.sampleTime, 0,
                                )
                                extractor.advance()
                            }
                        }
                    }

                    val outIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                    when {
                        outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val newFormat = codec.outputFormat
                            if (downmix == null) {
                                if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                                    sampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                                }
                                if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                                    channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                                }
                            }
                        }
                        outIndex >= 0 -> {
                            val isEos = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                            if (bufferInfo.size > 0) {
                                val outBuf = codec.getOutputBuffer(outIndex)!!
                                outBuf.position(bufferInfo.offset)
                                outBuf.limit(bufferInfo.offset + bufferInfo.size)
                                writePcm(outBuf, isEos)
                            } else if (isEos) {
                                writePcm(ByteBuffer.allocate(0), true)
                            }
                            codec.releaseOutputBuffer(outIndex, false)
                            if (isEos) outputDone = true
                        }
                    }
                }

                writeHeader(raf!!, dataBytesWritten, TARGET_SAMPLE_RATE)
                success = true
                outFile
            } finally {
                runCatching { decoder?.stop() }
                runCatching { decoder?.release() }
                runCatching { extractor.release() }
                runCatching { raf?.close() }
                if (!success) runCatching { outFile.delete() }
            }
        }

    private fun writeHeader(f: RandomAccessFile, dataSize: Long, sampleRate: Int) {
        val bb = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray(Charsets.US_ASCII))
        bb.putInt((36 + dataSize).toInt())
        bb.put("WAVE".toByteArray(Charsets.US_ASCII))
        bb.put("fmt ".toByteArray(Charsets.US_ASCII))
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(1)
        bb.putInt(sampleRate)
        bb.putInt(sampleRate * 2)
        bb.putShort(2)
        bb.putShort(16)
        bb.put("data".toByteArray(Charsets.US_ASCII))
        bb.putInt(dataSize.toInt())
        f.seek(0)
        f.write(bb.array())
    }
}
EOF_EXTRACTOR

# ------------------------------------------------------------------ AudioChunker.kt
cat > app/src/main/java/ir/livesub/AudioChunker.kt <<'EOF_CHUNKER'
package ir.livesub

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

data class AudioChunk(val file: File, val offsetMs: Long)

/**
 * تقسیم یک WAV مونو ۱۶بیتی به تکه‌های کوچک‌تر از سقف حجم Groq برای هر درخواست STT
 * (۲۵ مگابایت)، با نگهداری offset زمانی هر تکه تا بعداً timestampها جمع زده شوند
 * (بند ۳.۳ سند مهاجرت).
 */
object AudioChunker {

    private const val WAV_HEADER_BYTES = 44L
    private const val BYTES_PER_SAMPLE = 2L // PCM16 مونو
    private const val MAX_CHUNK_BYTES = 24L * 1024 * 1024 // کمی زیر سقف ۲۵ مگابایتی

    fun split(wavFile: File, sampleRate: Int, outDir: File): List<AudioChunk> {
        outDir.mkdirs()
        val totalDataBytes = wavFile.length() - WAV_HEADER_BYTES
        if (totalDataBytes <= MAX_CHUNK_BYTES) {
            return listOf(AudioChunk(wavFile, 0L))
        }

        // مرزهای تکه روی نمونه گرد می‌شوند تا وسط یک نمونهٔ ۱۶بیتی بریده نشود
        val samplesPerChunk = MAX_CHUNK_BYTES / BYTES_PER_SAMPLE
        val bytesPerChunk = samplesPerChunk * BYTES_PER_SAMPLE

        val chunks = ArrayList<AudioChunk>()
        RandomAccessFile(wavFile, "r").use { raf ->
            raf.seek(WAV_HEADER_BYTES)
            var remaining = totalDataBytes
            var index = 0
            var sampleOffset = 0L
            val buf = ByteArray(bytesPerChunk.toInt())
            while (remaining > 0) {
                val thisSize = minOf(bytesPerChunk, remaining).toInt()
                val read = raf.read(buf, 0, thisSize)
                if (read <= 0) break
                val outFile = File(outDir, "chunk_" + index + ".wav")
                writeWav(outFile, buf, read, sampleRate)
                val offsetMs = (sampleOffset * 1000) / sampleRate
                chunks.add(AudioChunk(outFile, offsetMs))
                sampleOffset += read / BYTES_PER_SAMPLE
                remaining -= read
                index++
            }
        }
        return chunks
    }

    private fun writeWav(outFile: File, data: ByteArray, length: Int, sampleRate: Int) {
        val bb = ByteBuffer.allocate(44 + length).order(ByteOrder.LITTLE_ENDIAN)
        bb.put("RIFF".toByteArray(Charsets.US_ASCII))
        bb.putInt(36 + length)
        bb.put("WAVE".toByteArray(Charsets.US_ASCII))
        bb.put("fmt ".toByteArray(Charsets.US_ASCII))
        bb.putInt(16)
        bb.putShort(1)
        bb.putShort(1)
        bb.putInt(sampleRate)
        bb.putInt(sampleRate * 2)
        bb.putShort(2)
        bb.putShort(16)
        bb.put("data".toByteArray(Charsets.US_ASCII))
        bb.putInt(length)
        bb.put(data, 0, length)
        outFile.writeBytes(bb.array())
    }
}
EOF_CHUNKER

# ------------------------------------------------------------------ SegmentMerger.kt
cat > app/src/main/java/ir/livesub/SegmentMerger.kt <<'EOF_MERGER'
package ir.livesub

/** خط زیرنویس آماده برای ترجمه: زمان‌بندی به میلی‌ثانیه (نسبت به کل فایل)، متن مبدأ. */
data class SubtitleLine(val startMs: Long, val endMs: Long, val sourceText: String)

/**
 * segmentهای خام ویسپر (که بر اساس مکث طبیعی گفتار جدا می‌شوند، نه لزوماً پایان جمله) را
 * بر اساس علائم پایان جمله ادغام می‌کند تا واحدهای ترجمه، جمله‌های کامل باشند
 * (بند ۳.۵ سند مهاجرت).
 */
object SegmentMerger {

    private val SENTENCE_END = Regex("[.!?…؟]\\s*$")
    private const val MAX_MERGE_MS = 12_000L
    private const val MAX_MERGE_CHARS = 220

    fun merge(segments: List<SttClient.RawSegment>): List<SubtitleLine> {
        val out = ArrayList<SubtitleLine>()
        var bufStart = -1L
        var bufEnd = -1L
        val bufText = StringBuilder()

        fun flush() {
            if (bufText.isNotBlank()) {
                out.add(SubtitleLine(bufStart, bufEnd, bufText.toString().trim()))
            }
            bufStart = -1L
            bufEnd = -1L
            bufText.clear()
        }

        for (seg in segments) {
            val text = seg.text.trim()
            if (text.isEmpty()) continue
            val startMs = (seg.startSec * 1000).toLong()
            val endMs = (seg.endSec * 1000).toLong()

            if (bufStart < 0) bufStart = startMs
            if (bufText.isNotEmpty()) bufText.append(' ')
            bufText.append(text)
            bufEnd = endMs

            val tooLong = (bufEnd - bufStart) > MAX_MERGE_MS || bufText.length > MAX_MERGE_CHARS
            if (SENTENCE_END.containsMatchIn(text) || tooLong) flush()
        }
        flush()
        return out
    }
}
EOF_MERGER

# ------------------------------------------------------------------ SrtBuilder.kt
cat > app/src/main/java/ir/livesub/SrtBuilder.kt <<'EOF_SRT'
package ir.livesub

import java.util.Locale

data class TranslatedLine(val startMs: Long, val endMs: Long, val text: String)

/** تبدیل خط‌های ترجمه‌شده + timestamp به متن استاندارد SRT (بند ۳.۷ سند مهاجرت). */
object SrtBuilder {

    fun build(lines: List<TranslatedLine>): String {
        val sb = StringBuilder()
        var n = 1
        for (line in lines) {
            val text = line.text.trim()
            // خط‌هایی که چیزی برای ترجمه نداشتند («-») به‌جای خط خالی، به‌کل حذف می‌شوند
            if (text.isEmpty() || text == "-") continue
            sb.append(n).append('\n')
            sb.append(ts(line.startMs)).append(" --> ").append(ts(line.endMs)).append('\n')
            sb.append(text).append('\n').append('\n')
            n++
        }
        return sb.toString()
    }

    private fun ts(msIn: Long): String {
        val ms = msIn.coerceAtLeast(0)
        val h = ms / 3_600_000
        val m = (ms % 3_600_000) / 60_000
        val s = (ms % 60_000) / 1000
        val msRem = ms % 1000
        return String.format(Locale.US, "%02d:%02d:%02d,%03d", h, m, s, msRem)
    }
}
EOF_SRT

# ------------------------------------------------------------------ ProcessingService.kt
cat > app/src/main/java/ir/livesub/ProcessingService.kt <<'EOF_SERVICE'
package ir.livesub

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

/**
 * جایگزین CaptureService.kt: کل پایپ‌لاین آفلاین (استخراج → تکه‌کردن → STT → ادغام →
 * ترجمه → SRT) را به‌عنوان foreground service با نوع dataSync اجرا می‌کند تا با رفتن
 * اپ به پس‌زمینه قطع نشود (بند ۳.۸ سند مهاجرت).
 */
class ProcessingService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var job: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            job?.cancel()
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START) return START_NOT_STICKY
        if (Bus.running.value) return START_NOT_STICKY

        val inputPath = intent.getStringExtra(EXTRA_INPUT_PATH) ?: return START_NOT_STICKY
        val language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "auto"
        val prompt = intent.getStringExtra(EXTRA_PROMPT)

        createChannel()
        ServiceCompat.startForeground(
            this, NOTIF_ID, notification("در حال آماده‌سازی…"),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )

        val prefs = Prefs(this)
        Bus.running.value = true
        Bus.lastError.value = null
        Bus.resultPath.value = null
        Bus.progress.value = 0f

        job = scope.launch { runPipeline(prefs, File(inputPath), language, prompt) }
        return START_NOT_STICKY
    }

    private suspend fun runPipeline(prefs: Prefs, inputFile: File, language: String, prompt: String?) {
        try {
            val workDir = File(cacheDir, "livesub_work").apply { mkdirs() }

            stage("استخراج صدا…", 0.02f)
            val wavFile = File(workDir, "audio.wav")
            AudioExtractor.extractMonoWav16k(this, Uri.fromFile(inputFile), wavFile)

            stage("تقسیم فایل صوتی…", 0.08f)
            val chunks = AudioChunker.split(
                wavFile, AudioExtractor.TARGET_SAMPLE_RATE, File(workDir, "chunks")
            )

            val stt = SttClient()
            val sttCfg = SttClient.Config(
                baseUrl = prefs.baseUrl,
                apiKey = prefs.apiKey,
                model = prefs.sttModel,
                language = language,
            )
            val allSegments = ArrayList<SttClient.RawSegment>()
            chunks.forEachIndexed { i, chunk ->
                stage(
                    "رونویسی تکهٔ " + (i + 1) + " از " + chunks.size + "…",
                    0.08f + 0.52f * (i.toFloat() / chunks.size),
                )
                val raw = stt.transcribeChunk(chunk.file.readBytes(), sttCfg, prompt)
                for (seg in raw) {
                    allSegments.add(
                        SttClient.RawSegment(
                            startSec = seg.startSec + chunk.offsetMs / 1000.0,
                            endSec = seg.endSec + chunk.offsetMs / 1000.0,
                            text = seg.text,
                        )
                    )
                }
                // فاصلهٔ کنترل‌شده بین درخواست‌های STT تا به سقف ۲۰ درخواست در دقیقه نخوریم
                if (i < chunks.size - 1) delay(3_200)
            }

            stage("ادغام جمله‌ها…", 0.62f)
            val cleaned = allSegments.filter { seg ->
                val text = TextClean.collapseRepeats(TextClean.normalize(seg.text))
                !TextClean.isNoise(text, ((seg.endSec - seg.startSec) * 1000).toInt())
            }
            val lines = SegmentMerger.merge(cleaned)

            stage("ترجمه…", 0.66f)
            val translator = BatchTranslator()
            val chatCfg = BatchTranslator.Config(
                baseUrl = prefs.baseUrl,
                apiKey = prefs.apiKey,
                model = prefs.chatModel,
            )
            val langEnglish = langOf(language).english
            val translated = ArrayList<TranslatedLine>()
            val batchSize = 15
            val contextTail = ArrayDeque<String>()
            var i = 0
            while (i < lines.size) {
                val batch = lines.subList(i, minOf(i + batchSize, lines.size))
                stage(
                    "ترجمهٔ خط " + (i + 1) + " از " + lines.size + "…",
                    0.66f + 0.28f * (i.toFloat() / lines.size.coerceAtLeast(1)),
                )
                val texts = batch.map { TextClean.normalize(it.sourceText) }
                val out = translator.translateBatch(texts, langEnglish, chatCfg, contextTail.toList())
                batch.forEachIndexed { j, line ->
                    translated.add(TranslatedLine(line.startMs, line.endMs, out.getOrElse(j) { "" }))
                }
                out.forEach { contextTail.addLast(it) }
                while (contextTail.size > 6) contextTail.removeFirst()
                i += batchSize
            }

            stage("ساخت فایل SRT…", 0.96f)
            val srtText = SrtBuilder.build(translated)
            val outDir = File(filesDir, "outputs").apply { mkdirs() }
            val outFile = File(outDir, baseName(inputFile) + ".srt")
            outFile.writeText(srtText, Charsets.UTF_8)

            Bus.resultPath.value = outFile.absolutePath
            Bus.progress.value = 1f
            Bus.stage.value = "تمام شد"
            updateNotification("زیرنویس آماده است")
        } catch (c: CancellationException) {
            Bus.stage.value = ""
        } catch (t: Throwable) {
            val friendly = TextClean.friendlyError(t.message ?: "خطای نامعلوم")
            Bus.lastError.value = friendly
            updateNotification("خطا: " + friendly)
        } finally {
            Bus.running.value = false
            stopSelf()
        }
    }

    private fun stage(text: String, progress: Float) {
        Bus.stage.value = text
        Bus.progress.value = progress
        updateNotification(text)
    }

    private fun baseName(f: File): String = f.nameWithoutExtension.ifBlank { "livesub" }

    private fun createChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "پردازش زیرنویس", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) }
            )
        }
    }

    private fun notification(text: String) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_sub)
        .setContentTitle("در حال ساخت زیرنویس")
        .setContentText(text)
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setContentIntent(
            PendingIntent.getActivity(
                this, 0, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        )
        .build()

    private fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        runCatching { nm.notify(NOTIF_ID, notification(text)) }
    }

    override fun onDestroy() {
        job?.cancel()
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "ir.livesub.action.START"
        const val ACTION_STOP = "ir.livesub.action.STOP"
        const val EXTRA_INPUT_PATH = "input_path"
        const val EXTRA_LANGUAGE = "language"
        const val EXTRA_PROMPT = "prompt"
        private const val CHANNEL_ID = "livesub_processing"
        private const val NOTIF_ID = 2001
    }
}
EOF_SERVICE

# ------------------------------------------------------------------ MainActivity.kt
cat > app/src/main/java/ir/livesub/MainActivity.kt <<'EOF_MAIN'
package ir.livesub

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.Typeface
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : ComponentActivity() {

    private lateinit var prefs: Prefs
    private var pendingInputFile: File? = null
    private var promptValue: String = ""
    private var pendingSavePath: String? = null

    private val pickDocument =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            if (uri != null) copyToWorkFile(uri)
        }

    private val permLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            Bus.uiTick.value = Bus.uiTick.value + 1
        }

    private val saveSrtLauncher =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/x-subrip")) { uri ->
            if (uri != null) writeResultTo(uri)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = Prefs(this)

        setContent {
            val ctx = LocalContext.current
            val vazir = remember { FontFamily(Typeface(VazirFont.get(ctx))) }
            MaterialTheme(colorScheme = darkColorScheme(), typography = vazirTypography(vazir)) {
                CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                    Surface(color = MaterialTheme.colorScheme.background) { Screen() }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Bus.uiTick.value = Bus.uiTick.value + 1
    }

    // ------------------------------------------------------- انتخاب فایل (SAF)

    private fun copyToWorkFile(uri: Uri) {
        Bus.lastError.value = null
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val name = queryDisplayName(uri) ?: "input"
                val dest = File(cacheDir, "picked_" + System.currentTimeMillis() + "_" + name)
                val input = contentResolver.openInputStream(uri) ?: error("فایل خوانده نشد")
                input.use { i -> dest.outputStream().use { o -> i.copyTo(o) } }
                pendingInputFile = dest
                Bus.selectedName.value = name
            } catch (t: Throwable) {
                Bus.lastError.value = "خواندن فایل ناموفق بود: " + (t.message ?: "")
            }
        }
    }

    private fun queryDisplayName(uri: Uri): String? = runCatching {
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            val idx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) c.getString(idx) else null
        }
    }.getOrNull()

    // ------------------------------------------------------- شروع/توقف پردازش

    private fun tryStart() {
        if (prefs.apiKey.isBlank()) {
            Bus.lastError.value = "کلید API گروک را وارد کنید"
            return
        }
        val input = pendingInputFile
        if (input == null) {
            Bus.lastError.value = "اول یک فایل ویدیو یا صوتی انتخاب کنید"
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val missing = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
            if (missing) permLauncher.launch(arrayOf(Manifest.permission.POST_NOTIFICATIONS))
        }
        val i = Intent(this, ProcessingService::class.java).apply {
            action = ProcessingService.ACTION_START
            putExtra(ProcessingService.EXTRA_INPUT_PATH, input.absolutePath)
            putExtra(ProcessingService.EXTRA_LANGUAGE, prefs.sourceLang)
            putExtra(ProcessingService.EXTRA_PROMPT, promptValue)
        }
        ContextCompat.startForegroundService(this, i)
    }

    private fun stopProcessing() {
        ContextCompat.startForegroundService(
            this, Intent(this, ProcessingService::class.java).setAction(ProcessingService.ACTION_STOP)
        )
    }

    private fun testKey() {
        Bus.stage.value = "در حال آزمایش کلید…"
        lifecycleScope.launch {
            Bus.stage.value = Net.checkKey(prefs.baseUrl, prefs.apiKey, prefs.sttModel, prefs.chatModel)
        }
    }

    // ------------------------------------------------------- دانلود/اشتراک‌گذاری (بند ۳.۹)

    private fun shareResult(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(this, "ir.livesub.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/x-subrip"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "اشتراک‌گذاری SRT"))
    }

    private fun requestSave(path: String) {
        pendingSavePath = path
        saveSrtLauncher.launch(File(path).name)
    }

    private fun writeResultTo(uri: Uri) {
        val path = pendingSavePath ?: return
        lifecycleScope.launch(Dispatchers.IO) {
            runCatching {
                val bytes = File(path).readBytes()
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            }
        }
    }

    // ------------------------------------------------------- رابط کاربری

    @Composable
    private fun Screen() {
        val running by Bus.running.collectAsState()
        val stage by Bus.stage.collectAsState()
        val progress by Bus.progress.collectAsState()
        val error by Bus.lastError.collectAsState()
        val resultPath by Bus.resultPath.collectAsState()
        val selectedName by Bus.selectedName.collectAsState()

        var key by remember { mutableStateOf(prefs.apiKey) }
        var baseUrl by remember { mutableStateOf(prefs.baseUrl) }
        var sttModel by remember { mutableStateOf(prefs.sttModel) }
        var chatModel by remember { mutableStateOf(prefs.chatModel) }
        var lang by remember { mutableStateOf(prefs.sourceLang) }
        var prompt by remember { mutableStateOf(promptValue) }
        var advanced by remember { mutableStateOf(false) }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("زیرنویس‌ساز فارسی", style = MaterialTheme.typography.titleLarge)
            Text(
                "یک فایل ویدیو یا صوتی را انتخاب کنید؛ رونویسی و ترجمهٔ فارسی به‌صورت دسته‌ای " +
                    "با گروک انجام می‌شود و یک فایل SRT قابل دانلود می‌سازد. اینترنت و کلید API " +
                    "همچنان لازم است — فقط دیگر لحظه‌به‌لحظه ارسال نمی‌شود.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Section("کلید گروک")
            OutlinedTextField(
                value = key,
                onValueChange = { key = it; prefs.apiKey = it.trim() },
                label = { Text("کلید API گروک") },
                supportingText = { Text("از console.groq.com، با gsk_ شروع می‌شود") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedButton(onClick = { testKey() }, modifier = Modifier.fillMaxWidth()) {
                Text("آزمایش کلید و مدل‌ها")
            }

            Section("فایل ورودی")
            OutlinedButton(
                onClick = { pickDocument.launch(arrayOf("video/*", "audio/*")) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(selectedName ?: "انتخاب فایل ویدیو یا صوتی")
            }

            Section("زبان صدا")
            Picker(
                label = "زبان مبدأ",
                options = LANGS.map { it.fa },
                selectedIndex = LANGS.indexOfFirst { it.code == lang }.coerceAtLeast(0),
                onSelect = { i -> lang = LANGS[i].code; prefs.sourceLang = lang },
            )

            OutlinedTextField(
                value = prompt,
                onValueChange = { prompt = it; promptValue = it },
                label = { Text("زمینه/اسم‌های خاص (اختیاری)") },
                supportingText = { Text("مثلاً اسم شخصیت‌ها یا موضوع فیلم، برای دقت بیشتر رونویسی") },
                modifier = Modifier.fillMaxWidth(),
            )

            TextButton(onClick = { advanced = !advanced }) {
                Text(if (advanced) "بستن تنظیمات پیشرفته" else "تنظیمات پیشرفته")
            }
            if (advanced) {
                OutlinedTextField(
                    value = baseUrl,
                    onValueChange = { baseUrl = it; prefs.baseUrl = it.trim() },
                    label = { Text("آدرس پایهٔ سرویس") },
                    supportingText = { Text(Prefs.GROQ_URL) },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = sttModel,
                    onValueChange = { sttModel = it; prefs.sttModel = it.trim() },
                    label = { Text("مدل شنیدن") },
                    supportingText = { Text(Prefs.STT_MODEL) },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = chatModel,
                    onValueChange = { chatModel = it; prefs.chatModel = it.trim() },
                    label = { Text("مدل ترجمه") },
                    supportingText = { Text("پیش‌فرض " + Prefs.CHAT_MODEL) },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
            }

            Button(
                onClick = { if (running) stopProcessing() else tryStart() },
                modifier = Modifier.fillMaxWidth().height(52.dp),
                colors = if (running) {
                    ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                } else {
                    ButtonDefaults.buttonColors()
                },
            ) {
                Text(
                    if (running) "توقف پردازش" else "شروع پردازش",
                    style = MaterialTheme.typography.titleMedium,
                )
            }

            if (running) {
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (stage.isNotBlank()) {
                Text(
                    stage,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val e = error
            if (e != null) {
                Text(e, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }

            val result = resultPath
            if (result != null) {
                Section("خروجی")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { shareResult(result) }, modifier = Modifier.weight(1f)) {
                        Text("اشتراک‌گذاری")
                    }
                    OutlinedButton(onClick = { requestSave(result) }, modifier = Modifier.weight(1f)) {
                        Text("ذخیره در مسیر دیگر")
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    @Composable
    private fun Section(text: String) = Text(
        text,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(top = 8.dp),
    )

    @Composable
    private fun Picker(
        label: String,
        options: List<String>,
        selectedIndex: Int,
        onSelect: (Int) -> Unit,
    ) {
        var expanded by remember { mutableStateOf(false) }
        Column(Modifier.fillMaxWidth()) {
            Text(
                label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
                Text(options.getOrElse(selectedIndex) { "" })
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEachIndexed { i, opt ->
                    DropdownMenuItem(
                        text = { Text(opt) },
                        onClick = { onSelect(i); expanded = false },
                    )
                }
            }
        }
    }

    private fun vazirTypography(f: FontFamily): Typography {
        val b = Typography()
        return Typography(
            titleLarge = b.titleLarge.copy(fontFamily = f),
            titleMedium = b.titleMedium.copy(fontFamily = f),
            bodyLarge = b.bodyLarge.copy(fontFamily = f),
            bodyMedium = b.bodyMedium.copy(fontFamily = f),
            bodySmall = b.bodySmall.copy(fontFamily = f),
            labelLarge = b.labelLarge.copy(fontFamily = f),
            labelMedium = b.labelMedium.copy(fontFamily = f),
            labelSmall = b.labelSmall.copy(fontFamily = f),
        )
    }
}
EOF_MAIN

echo "==> done"
