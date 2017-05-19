import ReactiveSwift
import Result
import XCTest
import PlaygroundSupport

class ViewModelTests: XCTestCase {
  let vm: MyViewModelType = MyViewModel()
  let alertMessage = TestObserver<String, NoError>()
  let submitButtonEnabled = TestObserver<Bool, NoError>()

  override func setUp() {
    super.setUp()
    self.vm.outputs.alertMessage.observe(self.alertMessage.observer)
    self.vm.outputs.submitButtonEnabled.observe(self.submitButtonEnabled.observer)
  }
  
  func testSubmitButtonEnabled() {
    self.vm.inputs.viewDidLoad()
    self.submitButtonEnabled.assertValues([false])
    
    self.vm.inputs.nameChanged(name: "Chris")
    self.submitButtonEnabled.assertValues([false])

    self.vm.inputs.emailChanged(email: "chris@gmail.com")
    self.submitButtonEnabled.assertValues([false])

    self.vm.inputs.passwordChanged(password: "secret123")
    self.submitButtonEnabled.assertValues([false, true])

    self.vm.inputs.nameChanged(name: "")
    self.submitButtonEnabled.assertValues([false, true, false])
  }
  
  func testSuccessfulSignup() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.nameChanged(name: "Lisa")
    self.vm.inputs.emailChanged(email: "lisa@rules.com")
    self.vm.inputs.passwordChanged(password: "password123")
    self.vm.inputs.submitButtonPressed()
    
    self.alertMessage.assertValues(["Successful"])
  }
  
  func testUnsuccessfulSignup() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.nameChanged(name: "Lisa")
    self.vm.inputs.emailChanged(email: "lisa@rules")
    self.vm.inputs.passwordChanged(password: "password123")
    self.vm.inputs.submitButtonPressed()
    
    self.alertMessage.assertValues(["Unsuccessful"])
  }
  
  func testTooManyAttempts() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.nameChanged(name: "Lisa")
    self.vm.inputs.emailChanged(email: "lisa@rules")
    self.vm.inputs.passwordChanged(password: "password123")
    
    self.vm.inputs.submitButtonPressed()
    self.vm.inputs.submitButtonPressed()
    self.vm.inputs.submitButtonPressed()
    
    self.alertMessage.assertValues(["Unsuccessful", "Unsuccessful", "Too Many Attempts"])
    self.submitButtonEnabled.assertValues([false, true, false])
    
    self.vm.inputs.emailChanged(email: "lisa@rules.com")
    self.submitButtonEnabled.assertValues([false, true, false])
  }
  

}




protocol MyViewModelInputs {
    func nameChanged(name: String?)
    func emailChanged(email: String?)
    func passwordChanged(password: String?)
    func submitButtonPressed()
    func viewDidLoad()
}

protocol MyViewModelOutputs {
  var alertMessage: Signal<String, NoError> { get }
  var submitButtonEnabled: Signal<Bool, NoError> { get }
}

protocol MyViewModelType {
  var inputs: MyViewModelInputs { get }
  var outputs: MyViewModelOutputs { get }
}

class MyViewModel: MyViewModelType, MyViewModelInputs, MyViewModelOutputs {

  init() {
    
    let formData = Signal.combineLatest(
      self.emailChangedProperty.signal,
      self.nameChangedProperty.signal,
      self.passwordChangedProperty.signal
    )
    
    let successfulSignupMessage = formData
      .sample(on: self.submitButtonPressedProperty.signal)
      .filter(isValid(email:name:password:))
      .map { _ in "Successful" }
    
    let submittedFormDataInvalid = formData
      .sample(on: self.submitButtonPressedProperty.signal)
      .filter { !isValid(email: $0, name: $1, password: $2) }
    
    let unsuccessfulSignupMessage = submittedFormDataInvalid
      .take(first: 2)
      .map { _ in "Unsuccessful" }
    
    let tooManyAttemptsMessage = submittedFormDataInvalid
      .skip(first: 2)
      .map { _ in "Too Many Attempts" }
    
    self.alertMessage = Signal.merge(
      successfulSignupMessage,
      unsuccessfulSignupMessage,
      tooManyAttemptsMessage
    )
    
    self.submitButtonEnabled = Signal.merge(
      self.viewDidLoadProperty.signal.map { _ in false },
      formData.map(isPresent(email:name:password:)),
      tooManyAttemptsMessage.map { _ in false }
    )
      .take(until: tooManyAttemptsMessage.map { _ in () } )
  }
  
  let nameChangedProperty = MutableProperty<String?>(nil)
  func nameChanged(name: String?) {
    self.nameChangedProperty.value = name
  }
  
  let emailChangedProperty = MutableProperty<String?>(nil)
  func emailChanged(email: String?) {
    self.emailChangedProperty.value = email
  }
  
  let passwordChangedProperty = MutableProperty<String?>(nil)
  func passwordChanged(password: String?) {
    self.passwordChangedProperty.value = password
  }
  
  let submitButtonPressedProperty = MutableProperty()
  func submitButtonPressed() {
    self.submitButtonPressedProperty.value = ()
  }
  
  let viewDidLoadProperty = MutableProperty()
  func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }
  
  let alertMessage: Signal<String, NoError>
  let submitButtonEnabled: Signal<Bool, NoError>

  var inputs: MyViewModelInputs { return self }
  var outputs: MyViewModelOutputs { return self }
}











class MyViewController: UIViewController {
  let vm: MyViewModelType = MyViewModel()
  
  let emailTextField = UITextField()
  let nameTextField = UITextField()
  let passwordTextField = UITextField()
  let submitButton = UIButton()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.emailTextField.addTarget(self,
                                  action: #selector(emailChanged),
                                  for: .editingChanged)
    self.nameTextField.addTarget(self,
                                 action: #selector(nameChanged),
                                 for: .editingChanged)
    self.passwordTextField.addTarget(self,
                                     action: #selector(passwordChanged),
                                     for: .editingChanged)
    self.submitButton.addTarget(self,
                                action: #selector(submitButtonPressed),
                                for: .touchUpInside)

    self.vm.outputs.alertMessage
      .observe(on: UIScheduler())
      .observeValues { [weak self] message in
        let alert = UIAlertController(title: nil,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default, handler: nil))
        self?.present(alert, animated: true, completion: nil)
    }
    
    self.vm.outputs.submitButtonEnabled
      .observe(on: UIScheduler())
      .observeValues { [weak self] enabled in self?.submitButton.isEnabled = enabled }
    
    self.vm.inputs.viewDidLoad()
  }

  func submitButtonPressed() {
    self.vm.inputs.submitButtonPressed()
  }

  func emailChanged() {
    self.vm.inputs.emailChanged(email: self.emailTextField.text)
  }

  func nameChanged() {
    self.vm.inputs.nameChanged(name: self.nameTextField.text)
  }

  func passwordChanged() {
    self.vm.inputs.passwordChanged(password: self.passwordTextField.text)
  }

  override func loadView() {
    self.view = UIView()
    self.view.backgroundColor = .white

    let rootStackView = UIStackView()
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    rootStackView.axis = .vertical
    rootStackView.spacing = 24
    rootStackView.layoutMargins = .init(top: 40, left: 24, bottom: 24, right: 24)
    rootStackView.isLayoutMarginsRelativeArrangement = true

    let titleLabel = UILabel()
    titleLabel.text = "Sign up!"
    titleLabel.font = .preferredFont(forTextStyle: .title1)
    titleLabel.textAlignment = .center

    let nameLabel = UILabel()
    nameLabel.text = "Name"
    nameLabel.font = .preferredFont(forTextStyle: .caption1)

    self.nameTextField.placeholder = "Name"
    self.nameTextField.borderStyle = .roundedRect
    self.nameTextField.autocorrectionType = .no

    let nameStackView = UIStackView()
    nameStackView.axis = .vertical
    nameStackView.spacing = 4
    nameStackView.addArrangedSubview(nameLabel)
    nameStackView.addArrangedSubview(self.nameTextField)

    let emailLabel = UILabel()
    emailLabel.text = "Email"
    emailLabel.font = .preferredFont(forTextStyle: .caption1)

    self.emailTextField.placeholder = "Email"
    self.emailTextField.borderStyle = .roundedRect
    self.emailTextField.autocorrectionType = .no

    let emailStackView = UIStackView()
    emailStackView.axis = .vertical
    emailStackView.spacing = 4
    emailStackView.addArrangedSubview(emailLabel)
    emailStackView.addArrangedSubview(self.emailTextField)

    let passwordLabel = UILabel()
    passwordLabel.text = "Password"
    passwordLabel.font = .preferredFont(forTextStyle: .caption1)

    self.passwordTextField.placeholder = "Password"
    self.passwordTextField.isSecureTextEntry = true
    self.passwordTextField.borderStyle = .roundedRect
    self.passwordTextField.autocorrectionType = .no

    let passwordStackView = UIStackView()
    passwordStackView.axis = .vertical
    passwordStackView.spacing = 4
    passwordStackView.addArrangedSubview(passwordLabel)
    passwordStackView.addArrangedSubview(self.passwordTextField)

    self.submitButton.setTitle("Sign up", for: .normal)
    self.submitButton.setTitleColor(.white, for: .normal)
    self.submitButton.setTitleColor(.gray, for: .highlighted)
    self.submitButton.setTitleColor(.gray, for: .disabled)
    self.submitButton.backgroundColor = .darkGray
    self.submitButton.layer.masksToBounds = true
    self.submitButton.layer.cornerRadius = 6

    self.view.addSubview(rootStackView)
    rootStackView.addArrangedSubview(titleLabel)
    rootStackView.addArrangedSubview(nameStackView)
    rootStackView.addArrangedSubview(emailStackView)
    rootStackView.addArrangedSubview(passwordStackView)
    rootStackView.addArrangedSubview(self.submitButton)

    NSLayoutConstraint.activate([
      rootStackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      rootStackView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      rootStackView.topAnchor.constraint(equalTo: self.view.topAnchor),
      rootStackView.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
      ])
  }
}

let vc = MyViewController()
vc.preferredContentSize.width = 300
vc.preferredContentSize.height = 400

PlaygroundPage.current.liveView = vc
ViewModelTests.defaultTestSuite().run()

