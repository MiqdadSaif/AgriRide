import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'add_vehicle_page.dart';

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
  String? _currentUserRole;

  bool _isLoginView = true;

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  Timer? _verificationTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.emailVerified) {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Email verified! Welcome to AgriRent!"),
                backgroundColor: Color(0xFF34D399),
              ),
            );
            // Force a rebuild to trigger AuthWrapper navigation
            setState(() {
              _user = currentUser;
            });
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  String? _validateUsername(String input)
  {
    if (input.isEmpty)
    {
      return 'Username cannot be empty.';
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(input))
    {
      return 'Username must be alphanumeric (A-Z, 0-9).';
    }
    return null;
  }

  bool _isValidEmail(String email)
  {
    final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  @override
  void initState() {
    super.initState();
    
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Check if email is verified
        await user.reload();
        final currentUser = _auth.currentUser;
        
        if (currentUser != null && !currentUser.emailVerified) {
          // Don't sign out during signup process - let AuthWrapper handle it
          // Only sign out if user is trying to access the app without verification
          setState(() {
            _user = currentUser;
            _currentUserRole = null;
          });
          return;
        }
        
        // If user is verified, load role (AuthWrapper will handle navigation)
        if (currentUser != null && currentUser.emailVerified) {
          await _loadUserRole(currentUser.uid);
        }
      }
      
      setState(() {
        _user = user;
      });
      if (user != null) {
        _loadUserRole(user.uid);
      } else {
        setState(() {
          _currentUserRole = null;
        });
      }
    });

    
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    });}

  Future<void> _loadUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      setState(() {
        _currentUserRole = doc.data()?['role'] as String?;
      });
    } catch (_) {
      setState(() {
        _currentUserRole = null;
      });
    }
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
   final username = _fullNameController.text.trim();
   final email = _emailController.text.trim();
   final usernameError = _validateUsername(username);
   if (usernameError != null)
   {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(usernameError),
         backgroundColor: Colors.red.shade400,
       ),
     );
     return;
   }

   if (!_isValidEmail(email))
   {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: const Text('Please enter a valid email address.'),
         backgroundColor: Colors.red.shade400,
       ),
     );
     return;
   }

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
        email: email,
        password: _passwordController.text.trim(),
      );
      await userCredential.user?.updateDisplayName(
        username,
      );

      // Send email verification link
      bool emailSent = false;
      try {
        await userCredential.user?.sendEmailVerification();
        emailSent = true;
      } catch (e) {
        if (e.toString().contains('too-many-requests')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Too many requests. Please wait a few minutes before trying again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send verification email: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      
      await _firestore.collection('users').doc(userCredential.user!.uid).set(
        {
        'email': email,
        'displayName': username,
        'role': _selectedRole!.toLowerCase(),
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      
      await userCredential.user?.reload();
      final updatedUser = _auth.currentUser;

      setState(() => _user = updatedUser);

      if (mounted) 
      {
        if (emailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account created! Verification email sent. Please check your inbox (including spam folder)."),
              backgroundColor: Color(0xFF34D399),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account created! Please try logging in to resend verification email."),
              backgroundColor: Color(0xFF34D399),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) 
    {
      String errorMessage;
      Color errorColor = Colors.red;
      
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email address.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please choose a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = 'Sign up failed: ${e.message ?? 'Unknown error occurred'}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
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
      
      // Check if email is verified
      if (userCredential.user != null) {
        await userCredential.user!.reload();
        final currentUser = _auth.currentUser;
        
        if (currentUser != null && !currentUser.emailVerified) {
          // Don't sign out - just show verification message and start checking
          setState(() => _user = currentUser);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Please verify your email address before logging in. Check your inbox (including spam folder)."),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Resend',
                  textColor: Colors.white,
                  onPressed: () {
                    _resendVerificationEmailForLogin();
                  },
                ),
              ),
            );
          }
          
          // Start checking for verification every 3 seconds
          _startVerificationCheck();
          return;
        }
      }
      
      setState(() => _user = userCredential.user);
      if (mounted) 
      {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(
          content: Text("Login successful! Welcome back!"),
          backgroundColor: Color(0xFF34D399),
        ));
      }
    } 
    on FirebaseAuthException catch (e) 
    {
      String errorMessage;
      Color errorColor = Colors.red;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Email or password is wrong.';
          break;
        case 'wrong-password':
          errorMessage = 'Email or password is wrong.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'invalid-credential':
          errorMessage = 'Email or password is wrong.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = 'Email or password is wrong.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } 
    catch (e) 
    {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email or password is wrong.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
            : _buildProfileView(),),);}

  
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
        ],),);}

  
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
            ),),],);}


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
          label: 'Username (alphanumeric)',
          icon: Icons.person_outline,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
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
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
        ),),); }

  
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
        ),),);}

  
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
),);}

  
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
                },), ),
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
                  });},),),],),],);}

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
              ),),],),),);}

  
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
          const SizedBox(height: 10),
          // Email verification status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _user!.emailVerified ? Icons.verified : Icons.warning,
                color: _user!.emailVerified ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _user!.emailVerified ? 'Email Verified' : 'Email Not Verified',
                style: TextStyle(
                  fontSize: 12,
                  color: _user!.emailVerified ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          if (!_user!.emailVerified) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _resendVerificationEmail,
              child: const Text(
                'Resend Verification Email',
                style: TextStyle(color: Color(0xFF34D399)),
              ),
            ),
          ],
          const SizedBox(height: 40),
          if (_currentUserRole == 'Owner') ...[
            ElevatedButton.icon(
              onPressed: () async {
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddVehiclePage()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Add Vehicle',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),],),);}

  Future<void> _resendVerificationEmail() async {
    try {
      await _user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Color(0xFF34D399),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('too-many-requests')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many requests. Please wait 1-2 hours before trying again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send verification email: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _resendVerificationEmailForLogin() async {
    try {
      // Use the current user to send verification email
      final currentUser = _auth.currentUser;
      
      if (currentUser != null) {
        await currentUser.sendEmailVerification();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent! Please check your inbox (including spam folder).'),
              backgroundColor: Color(0xFF34D399),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('too-many-requests')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many requests. Please wait 1-2 hours before trying again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send verification email: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }}
