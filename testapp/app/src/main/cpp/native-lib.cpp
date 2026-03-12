#include <jni.h>
#include <string>

static int counter = 0;

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_testapp_MainActivity_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    char buffer[128];
    sprintf(buffer, "Hello from C++ %d", counter++);
    return env->NewStringUTF(buffer);  // BREAKPOINT
}