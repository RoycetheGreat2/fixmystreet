// ...existing code...
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFF1025A1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(70), // Thickness of the white border
                decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // Border color
                ),  
              ),
              const SizedBox(height: 50),
              Text(
                'Welcome Back',
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to your account to continue',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  color: const Color.fromARGB(255, 213, 211, 211),
                ),
              ),
              
              const SizedBox(height: 50),
              // white square container (320x320)
              SizedBox(
                width: 320,
                // remove fixed height
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 25),
                        Text('Username/Email',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            
                          ),
                        ),
                          TextField(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        const SizedBox(height: 25),
                        Text('Password',
                            style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
              
                          ),
                        ),
                          TextField(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                            obscureText: true,
                          ),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1025A1), // Button background color
                              foregroundColor: Colors.white, // Text color
                              shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // Rounded corners
                              ),
                            ),
                            onPressed: () {
                              //For login action amogussy
                            },
                            child: Text('Log in', 
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              )
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Don’t have an account?',
                                style: GoogleFonts.inter(),
                              ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/signup');
                              },
                              child: Text(
                                'Sign up',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ...existing code...