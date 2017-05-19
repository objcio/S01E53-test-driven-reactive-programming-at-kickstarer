import Foundation

private let pattern = "[a-zA-Z0-9\\+\\.\\_\\%\\-\\+]{1,256}\\@" +
  "[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\." +
"[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+"

public func isValidEmail(_ email: String) -> Bool {

  let regex = try? NSRegularExpression(
    pattern: pattern,
    options: []
  )

  let range = NSRange.init(location: 0, length: email.characters.count)
  return regex?.firstMatch(in: email, options: [], range: range) != nil
}

public func isPresent(email: String?, name: String?, password: String?) -> Bool {
  guard let email = email, let name = name, let password = password
    else { return false }
  return email.characters.count > 0
    && name.characters.count > 0
    && password.characters.count > 0
}

public func isValid(email: String?, name: String?, password: String?) -> Bool {
  guard let email = email, let name = name, let password = password
    else { return false }
  return isValidEmail(email)
    && name.characters.count > 0
    && password.characters.count > 0
}
