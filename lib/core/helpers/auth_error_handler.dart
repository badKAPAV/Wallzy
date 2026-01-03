class AuthErrorHandler {
  static String getUserFriendlyMessage(Object error) {
    // We use dynamic access to avoid importing firebase_auth directly if not needed,
    // or we can import it. Let's rely on code strings.
    String code = "unknown";
    try {
      // ignore: avoid_dynamic_calls
      code = (error as dynamic).code;
    } catch (_) {
      // If error doesn't have a code, return default
      return "An unexpected error occurred. Please try again.";
    }

    switch (code) {
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'email-already-in-use':
        return "An account already exists with this email.";
      case 'invalid-email':
        return "Please enter a valid email address.";
      case 'weak-password':
        return "The password is too weak. Please choose a stronger one.";
      case 'network-request-failed':
        return "Network error. Please check your connection.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'operation-not-allowed':
        return "This sign-in method is not enabled.";
      case 'channel-error':
        return "Please fill in all fields.";
      case 'invalid-credential':
        return "Incorrect email or password.";
      case 'user-disabled':
        return "This user account has been disabled.";
      case 'credential-already-in-use':
        return "This credential is already associated with another account.";
      default:
        // Fallback to the raw message if available, or generic
        try {
          // ignore: avoid_dynamic_calls
          return (error as dynamic).message ?? "Authentication failed.";
        } catch (_) {
          return "Authentication failed. Please try again.";
        }
    }
  }
}
