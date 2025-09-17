import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailPasswordAuthPage extends StatefulWidget {
  const EmailPasswordAuthPage({super.key});

  @override
  State<EmailPasswordAuthPage> createState() => _EmailPasswordAuthPageState();
}

class _EmailPasswordAuthPageState extends State<EmailPasswordAuthPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  bool _isLoading = false;
  User? _user;
  String? _passwordError;
  String? _selectedRole;

  bool _isLoginView = true;

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
    });

    
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    });
  }

  
  String? _validatePassword(String? password) 
  {

    if (password == null || password.isEmpty) 
    {
      return 'Password cannot be empty.';
    }
    if (password.length < 8) 
    {
      return 'Password must be at least 8 characters long.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) 
    {
      return '• Must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return '• Must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return '• Must contain at least one number.';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return '• Must contain at least one special character.';
    }
    return null; 
  }

  Future<void> _signUp() async
   {
    
    final password = _passwordController.text;
    final validationError = _validatePassword(password);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(// this line is used to show the message in screen 
        SnackBar
        (
          content: Text(validationError),
          backgroundColor: Colors.red.shade400,
        ),
      );
      setState(() 
      {
        _passwordError = validationError;
      });
      return;
    }

    if (password != _confirmPasswordController.text) 
    {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    if (_selectedRole == null) 
    {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a role!")));
      return;
    }

    setState(() => _isLoading = true);

    try 
    {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await userCredential.user?.updateDisplayName(
        _fullNameController.text.trim(),
      );

      
      await _firestore.collection('users').doc(userCredential.user!.uid).set(
        {
        'email': _emailController.text.trim(),
        'displayName': _fullNameController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      
      await userCredential.user?.reload();
      final updatedUser = _auth.currentUser;

      setState(() => _user = updatedUser);

      if (mounted) 
      {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
      }
    } on FirebaseAuthException catch (e) 
    {
      if (mounted) 
      {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Sign Up Error: ${e.message}")));
      }
    } 
    finally
     {
      if (mounted)
       {
        setState(() => _isLoading = false);
       } 
    }
  }

  Future<void> _login() async
   {
    setState(() => _isLoading = true);
    try 
    {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() => _user = userCredential.user);
      if (mounted) 
      {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Login successful!")));
      }
    } 
    on FirebaseAuthException catch (e) 
    {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Login Error: ${e.message}")));
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async 
  {
    await _auth.signOut();
    
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _fullNameController.clear();
    setState(() {
      _user = null;
      _isLoginView = true;
      _selectedRole = null;
    });
  }

  @override
  Widget build(BuildContext context)
   {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF34D399))
            : _user == null
            ? _buildAuthForm()
            : _buildProfileView(),
      ),
    );
  }

  
  Widget _buildAuthForm() 
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          _buildLogo(),
          const SizedBox(height: 40),
          
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _isLoginView ? _buildLoginView() : _buildSignUpView(),
          ),
          const SizedBox(height: 20),
          _buildToggleAuthMode(),
            
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981), 
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.agriculture, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 8),
        if (!_isLoginView) 
          const Text(
            'AGRI RENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }


  Widget _buildLoginView() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to your account',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 30),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          isObscured: _isPasswordObscured,
          onToggle: () {
            setState(() {
              _isPasswordObscured = !_isPasswordObscured;
            });
          },
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        _buildAuthButton('Sign In', _login),
      ],
    );
  }

  
  Widget _buildSignUpView() {
    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Join AgriRent today',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 30),
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Password',
          isObscured: _isPasswordObscured,
          errorText: _passwordError,
          onToggle: () {
            setState(() {
              _isPasswordObscured = !_isPasswordObscured;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          isObscured: _isConfirmPasswordObscured,
          onToggle: () {
            setState(() {
              _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
            });
          },
        ),
        const SizedBox(height: 20),
        _buildRoleSelection(),
        const SizedBox(height: 30),
        _buildAuthButton('Create Account', _signUp),
      ],
    );
  }

  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF34D399)),
        ),
      ),
    );
  }

  
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscured,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        errorText: errorText,
        errorStyle: TextStyle(color: Colors.red.shade400),
        suffixIcon: IconButton(
          icon: Icon(
            isObscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF34D399)),
        ),
      ),
    );
  }

  
  Widget _buildAuthButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF34D399),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  
  Widget _buildToggleAuthMode() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.grey)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text("OR", style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLoginView
                  ? "Don't have an account? "
                  : "Already have an account? ",
              style: const TextStyle(color: Colors.grey),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isLoginView = !_isLoginView;
                });
              },
              child: Text(
                _isLoginView ? 'Sign Up' : 'Sign In',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Your Role',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRoleOption(
                icon: Icons.agriculture,
                title: 'Farmer',
                subtitle: 'Rent vehicles',
                isSelected: _selectedRole == 'Farmer',
                onTap: () {
                  setState(() {
                    _selectedRole = 'Farmer';
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleOption(
                icon: Icons.business,
                title: 'Owner',
                subtitle: 'List vehicles',
                isSelected: _selectedRole == 'Owner',
                onTap: () {
                  setState(() {
                    _selectedRole = 'Owner';
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) 
  {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF34D399).withOpacity(0.15) : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF34D399) : Colors.grey.shade800,
            width: isSelected ? 2 : 1,
          ),  
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF34D399) : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF34D399) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? const Color(0xFF34D399).withOpacity(0.8) : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildProfileView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle, size: 100, color: Color(0xFF34D399)),
          const SizedBox(height: 20),
          Text(
            _user!.displayName ?? 'Welcome!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _user!.email ?? "No Email",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
