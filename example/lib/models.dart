// This file demonstrates multiple classes in one file - non-compliant

/// Represents a user in the system
class User {
  final String name;
  final int age;

  User(this.name, this.age);

  void greet() {
    print('Hello, I am $name');
  }
}

/// Represents a product
class Product {
  final String name;
  final double price;

  Product(this.name, this.price);

  void display() {
    print('$name costs \$${price.toStringAsFixed(2)}');
  }
}

/// Utility class for validation - this makes it even more non-compliant
class Validator {
  static bool isValidEmail(String email) {
    return email.contains('@');
  }

  static bool isValidAge(int age) {
    return age >= 0 && age <= 150;
  }
}
