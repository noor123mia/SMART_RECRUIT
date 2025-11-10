import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/CandidateMatchingScreen.dart';
import 'package:flutter_application_2/screens/DraftJobsScreen.dart';
import 'package:flutter_application_2/screens/In_App_Chat_Screen.dart';
import 'package:flutter_application_2/screens/InterviewQuestionsScreen.dart';
import 'package:flutter_application_2/screens/OfferLetterAutomationScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_application_2/services/supabase_config.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
//import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: MyApp(),
    ),
  );
}

class UserProvider extends ChangeNotifier {
  firebase_auth.User? _user;
  Map<String, dynamic>? _userData;
  bool _isRecruiter = false;
  bool _isDarkMode = false;
  bool _isLoading = false;
  String _preferredLanguage = 'English';
  bool _enableNotifications = true;

  firebase_auth.User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isRecruiter => _isRecruiter;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  String get preferredLanguage => _preferredLanguage;
  bool get enableNotifications => _enableNotifications;

  void setUser(firebase_auth.User? user) {
    _user = user;
    notifyListeners();
  }

  void setUserData(Map<String, dynamic>? userData) {
    _userData = userData;
    _isRecruiter = userData?['userType'] == 'recruiter';
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _userData = null;
    _isRecruiter = false;
    notifyListeners();
  }

  void setIsLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setPreferredLanguage(String language) {
    _preferredLanguage = language;
    notifyListeners();
  }

  void toggleNotifications() {
    _enableNotifications = !_enableNotifications;
    notifyListeners();
  }
}

final appTheme = ThemeData(
  primaryColor: Color(0xFF1E3A8A), // Rich navy blue
  primaryColorLight: Color(0xFF3151A6),
  secondaryHeaderColor: Color(0xFF0D9488), // Teal accent
  scaffoldBackgroundColor: Color(0xFFF9FAFB),
  fontFamily:
      'Poppins', // Assuming Poppins is available, otherwise system font will be used
  textTheme: TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1F2937),
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1F2937),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Color(0xFF1F2937),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color(0xFF6B7280),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
  ),
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
    color: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
    toolbarTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFF0D9488),
    surface: Colors.white,
    background: Color(0xFFF9FAFB),
    error: Color(0xFFEF4444),
  ),
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return MaterialApp(
      title: 'SmartRecruit',
      theme: appTheme,
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF1E3A8A),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF0D9488),
        ),
      ),
      themeMode: userProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      //home: userProvider.isLoading
      // ? LoadingScreen()
      //: (userProvider.userData != null ? HomeScreen() : AuthWrapper()),

      // Set up routing
      initialRoute: '/',
      routes: {
        '/': (context) => userProvider.isLoading
            ? LoadingScreen()
            : (userProvider.userData != null ? HomeScreen() : AuthWrapper()),
        '/DraftJobsScreen': (context) => DraftJobsScreen(),
        '/HomeScreen': (context) => HomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final firebase_auth.User? user = snapshot.data as firebase_auth.User?;

          if (user == null) {
            userProvider.setUser(null);
            return WelcomeScreen();
          } else {
            userProvider.setUser(user);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done) {
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final data =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    userProvider.setUserData(data);

                    final userData = userProvider.userData;

                    // Redirect based on userType
                    if (userData?['userType'] == 'recruiter') {
                      if (userData?['isVerified'] == false) {
                        return VerificationScreen();
                      } else {
                        return HomeScreen();
                      }
                    } else if (userData?['userType'] == 'jobseeker') {
                      // Check if this is first login (profile not completed)
                      if (userData?['profileCompleted'] == null ||
                          userData?['profileCompleted'] == false) {
                        // First time login - show profile setup screen
                        return ResumeUploadScreen(); // or your ResumeUploadScreen
                      } else {
                        // Returning user - show home screen
                        return HomeScreen();
                      }
                    } else {
                      return HomeScreen();
                    }
                  }
                }
                return LoadingScreen(); // Waiting for Firestore
              },
            );
          }
        }
        return LoadingScreen(); // Waiting for auth
      },
    );
  }
}
/////////////////////////////////////////////////////////////

// Required dependencies (add to pubspec.yaml):
//   firebase_core, cloud_firestore, firebase_auth
//   supabase_flutter, file_picker, image_picker, path_provider, open_file
//   intl, timeago

/////////////////////////////////////////////////

/*

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({Key? key}) : super(key: key);

  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  bool _isInitialScreen = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isInitialScreen ? 'Create Your Profile' : 'Your Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_isInitialScreen)
            TextButton(
              onPressed: () => _navigateToHomeScreen(),
              child: Text(
                'Skip For Now',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body:
          _isInitialScreen ? _buildInitialScreen() : _buildProfileFormScreen(),
    );
  }

  // Initial screen with resume upload option
  Widget _buildInitialScreen() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(height: 24),
          Text(
            'Create Your Job Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Upload your resume to quickly fill your profile or create it manually',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _pickAndUploadResume,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file),
                SizedBox(width: 10),
                Text('Upload Resume', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          SizedBox(height: 20),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            onPressed: () {
              setState(() {
                _isInitialScreen = false;
              });
            },
            child: Text('Skip and Continue', style: TextStyle(fontSize: 16)),
          ),
          SizedBox(height: 20),
          if (_isUploading)
            Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Uploading resume...'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfileFormScreen() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                _buildSectionTitle('Profile Picture'),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickProfilePicture,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
                                  ? Icon(Icons.person,
                                      size: 60, color: Colors.grey[600])
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            icon: Icon(Icons.camera_alt),
                            label: Text('Upload Profile Picture'),
                            onPressed: _pickProfilePicture,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Resume status (if uploaded)
                if (_resumeFile != null)
                  Card(
                    margin: EdgeInsets.only(bottom: 16),
                    color: Colors.green[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resume Uploaded',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _resumeFile?.path.split('/').last ??
                                      'Resume file',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.upload_file, color: Colors.blue),
                            onPressed: _pickAndUploadResume,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Personal Information Section
                _buildSectionTitle('Personal Information'),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Full Name Field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            hintText: 'First and Last Name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Professional Title Field
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Professional Title',
                            prefixIcon: Icon(Icons.work),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your professional title';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Phone Number Field
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Location Field
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            prefixIcon: Icon(Icons.location_on),
                            hintText: 'City, Country',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your location';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // LinkedIn/Portfolio/Website Field
                        TextFormField(
                          controller: _websiteController,
                          decoration: InputDecoration(
                            labelText: 'LinkedIn/Portfolio/Website',
                            prefixIcon: Icon(Icons.link),
                            hintText: 'https://',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  ),
                ),

                // Professional Summary Section
                _buildSectionTitle('Professional Summary'),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a short, compelling summary highlighting your experience, key skills, and expertise.',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _summaryController,
                          decoration: InputDecoration(
                            labelText: 'Professional Summary',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your professional summary';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Work Experience Section
                _buildSectionTitle('Work Experience'),
                ..._workExperienceWidgets(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Work Experience'),
                      onPressed: _addWorkExperience,
                    ),
                  ),
                ),

                // Education & Certifications Section
                _buildSectionTitle('Education & Certifications'),
                ..._educationWidgets(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Education'),
                      onPressed: _addEducation,
                    ),
                  ),
                ),

                // Skills Section
                _buildSectionTitle('Skills'),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Technical Skills
                        Text(
                          'Technical/Hard Skills',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._selectedTechnicalSkills.map((skill) => Chip(
                                  label: Text(skill),
                                  deleteIcon: Icon(Icons.close, size: 18),
                                  onDeleted: () => _removeTechnicalSkill(skill),
                                )),
                            ActionChip(
                              avatar: Icon(Icons.add, size: 18),
                              label: Text('Add'),
                              onPressed: _showTechnicalSkillsDialog,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Soft Skills
                        Text(
                          'Soft Skills',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._selectedSoftSkills.map((skill) => Chip(
                                  label: Text(skill),
                                  deleteIcon: Icon(Icons.close, size: 18),
                                  onDeleted: () => _removeSoftSkill(skill),
                                )),
                            ActionChip(
                              avatar: Icon(Icons.add, size: 18),
                              label: Text('Add'),
                              onPressed: _showSoftSkillsDialog,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Add New Skills with Proficiency
                        Text(
                          'Custom Skills',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        ..._customSkillWidgets(),
                        OutlinedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('Add Custom Skill'),
                          onPressed: _addCustomSkill,
                        ),
                      ],
                    ),
                  ),
                ),

                // Job Preferences Section
                _buildSectionTitle('Job Preferences'),
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Desired Job Title/Role
                        TextFormField(
                          controller: _desiredRoleController,
                          decoration: InputDecoration(
                            labelText: 'Desired Job Title/Role',
                            prefixIcon: Icon(Icons.work_outline),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Industry Preference
                        TextFormField(
                          controller: _industryPreferenceController,
                          decoration: InputDecoration(
                            labelText: 'Industry Preference',
                            prefixIcon: Icon(Icons.business),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Job Type
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Job Type',
                            prefixIcon: Icon(Icons.business_center),
                          ),
                          value: _jobType,
                          items: [
                            'Full-time',
                            'Part-time',
                            'Contract',
                            'Remote',
                            'Hybrid'
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _jobType = newValue;
                              });
                            }
                          },
                        ),
                        SizedBox(height: 16),

                        // Expected Salary Range
                        TextFormField(
                          controller: _salaryExpectationController,
                          decoration: InputDecoration(
                            labelText: 'Expected Salary Range (Optional)',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Location Preference
                        TextFormField(
                          controller: _locationPreferenceController,
                          decoration: InputDecoration(
                            labelText: 'Location Preference',
                            prefixIcon: Icon(Icons.location_city),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Projects & Achievements Section
                _buildSectionTitle('Projects & Achievements'),
                ..._projectWidgets(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Project'),
                      onPressed: _addProject,
                    ),
                  ),
                ),

                // Languages Known Section
                _buildSectionTitle('Languages'),
                ..._languageWidgets(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add Language'),
                      onPressed: _addLanguage,
                    ),
                  ),
                ),

                // Submit Button
                SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isUploading ? null : _saveProfileData,
                    child: Text(
                      'Save Profile',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Section title widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

// Work Experience Section Widgets
  List<Widget> _workExperienceWidgets() {
    return _workExperiences.asMap().entries.map((entry) {
      int idx = entry.key;
      WorkExperience exp = entry.value;
      return Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Experience ${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeWorkExperience(idx),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                initialValue: exp.jobTitle,
                decoration: InputDecoration(
                  labelText: 'Job Title',
                  prefixIcon: Icon(Icons.work),
                ),
                onChanged: (value) => _workExperiences[idx].jobTitle = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter job title';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: exp.company,
                decoration: InputDecoration(
                  labelText: 'Company Name',
                  prefixIcon: Icon(Icons.business),
                ),
                onChanged: (value) => _workExperiences[idx].company = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter company name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: exp.startDate,
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: Icon(Icons.calendar_today),
                        hintText: 'MM/YYYY',
                      ),
                      onChanged: (value) =>
                          _workExperiences[idx].startDate = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: exp.endDate,
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        prefixIcon: Icon(Icons.calendar_today),
                        hintText: 'MM/YYYY or Present',
                      ),
                      onChanged: (value) =>
                          _workExperiences[idx].endDate = value,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: exp.responsibilities,
                decoration: InputDecoration(
                  labelText: 'Key Responsibilities & Achievements',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                onChanged: (value) =>
                    _workExperiences[idx].responsibilities = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your responsibilities';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Education Widgets
  List<Widget> _educationWidgets() {
    return _educations.asMap().entries.map((entry) {
      int idx = entry.key;
      Education edu = entry.value;
      return Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Education ${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeEducation(idx),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                initialValue: edu.degree,
                decoration: InputDecoration(
                  labelText: 'Degree/Diploma',
                  prefixIcon: Icon(Icons.school),
                ),
                onChanged: (value) => _educations[idx].degree = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your degree';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: edu.institution,
                decoration: InputDecoration(
                  labelText: 'University/Institution',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                onChanged: (value) => _educations[idx].institution = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter institution name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: edu.graduationYear,
                decoration: InputDecoration(
                  labelText: 'Year of Graduation',
                  prefixIcon: Icon(Icons.date_range),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _educations[idx].graduationYear = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter graduation year';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: edu.certifications,
                decoration: InputDecoration(
                  labelText: 'Certifications',
                  alignLabelWithHint: true,
                  hintText: 'List your certifications, one per line',
                ),
                maxLines: 3,
                onChanged: (value) => _educations[idx].certifications = value,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Custom Skills Widgets
  List<Widget> _customSkillWidgets() {
    return _customSkills.asMap().entries.map((entry) {
      int idx = entry.key;
      CustomSkill skill = entry.value;
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: skill.name,
                decoration: InputDecoration(
                  labelText: 'Skill Name',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                onChanged: (value) => _customSkills[idx].name = value,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Proficiency',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                value: skill.level,
                items:
                    ['Beginner', 'Intermediate', 'Expert'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _customSkills[idx].level = newValue;
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeCustomSkill(idx),
            ),
          ],
        ),
      );
    }).toList();
  }

// Project Widgets
  List<Widget> _projectWidgets() {
    return _projects.asMap().entries.map((entry) {
      int idx = entry.key;
      Project project = entry.value;
      return Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Project ${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeProject(idx),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                initialValue: project.name,
                decoration: InputDecoration(
                  labelText: 'Project Name',
                  prefixIcon: Icon(Icons.folder_special),
                ),
                onChanged: (value) => _projects[idx].name = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter project name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: project.description,
                decoration: InputDecoration(
                  labelText: 'Project Description',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onChanged: (value) => _projects[idx].description = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe the project';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: project.role,
                decoration: InputDecoration(
                  labelText: 'Your Role & Contributions',
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
                onChanged: (value) => _projects[idx].role = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe your role';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: project.outcome,
                decoration: InputDecoration(
                  labelText: 'Outcome/Impact',
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
                onChanged: (value) => _projects[idx].outcome = value,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Language Widgets
  List<Widget> _languageWidgets() {
    return _languages.asMap().entries.map((entry) {
      int idx = entry.key;
      Language language = entry.value;
      return Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: language.name,
                  decoration: InputDecoration(
                    labelText: 'Language',
                    prefixIcon: Icon(Icons.language),
                  ),
                  onChanged: (value) => _languages[idx].name = value,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Proficiency',
                    prefixIcon: Icon(Icons.grade),
                  ),
                  value: language.proficiency,
                  items: ['Basic', 'Intermediate', 'Fluent', 'Native']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _languages[idx].proficiency = newValue;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeLanguage(idx),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Add these methods to your class for managing form fields
  void _pickProfilePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
        _isProfileImageChanged = true;
      });
    }
  }

  void _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _resumeFile = File(result.files.single.path!);
        _isResumeChanged = true;
      });
    }
  }

  void _addWorkExperience() {
    setState(() {
      _workExperiences.add(WorkExperience());
    });
  }

  void _removeWorkExperience(int index) {
    setState(() {
      _workExperiences.removeAt(index);
    });
  }

  void _addEducation() {
    setState(() {
      _educations.add(Education());
    });
  }

  void _removeEducation(int index) {
    setState(() {
      _educations.removeAt(index);
    });
  }

  void _addCustomSkill() {
    setState(() {
      _customSkills.add(CustomSkill());
    });
  }

  void _removeCustomSkill(int index) {
    setState(() {
      _customSkills.removeAt(index);
    });
  }

  void _showTechnicalSkillsDialog() {
    final TextEditingController _skillController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Technical Skill'),
          content: TextField(
            controller: _skillController,
            decoration: InputDecoration(
              hintText: 'Enter skill name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                if (_skillController.text.isNotEmpty) {
                  setState(() {
                    _selectedTechnicalSkills.add(_skillController.text);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeTechnicalSkill(String skill) {
    setState(() {
      _selectedTechnicalSkills.remove(skill);
    });
  }

  void _showSoftSkillsDialog() {
    final TextEditingController _skillController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Soft Skill'),
          content: TextField(
            controller: _skillController,
            decoration: InputDecoration(
              hintText: 'Enter skill name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                if (_skillController.text.isNotEmpty) {
                  setState(() {
                    _selectedSoftSkills.add(_skillController.text);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeSoftSkill(String skill) {
    setState(() {
      _selectedSoftSkills.remove(skill);
    });
  }

  void _addProject() {
    setState(() {
      _projects.add(Project());
    });
  }

  void _removeProject(int index) {
    setState(() {
      _projects.removeAt(index);
    });
  }

  void _addLanguage() {
    setState(() {
      _languages.add(Language());
    });
  }

  void _removeLanguage(int index) {
    setState(() {
      _languages.removeAt(index);
    });
  }

  void _saveProfileData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Create profile data object
        Map<String, dynamic> profileData = {
          'personalInfo': {
            'name': _nameController.text,
            'professionalTitle': _titleController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'location': _locationController.text,
            'website': _websiteController.text,
          },
          'professionalSummary': _summaryController.text,
          'workExperiences': _workExperiences.map((e) => e.toJson()).toList(),
          'educations': _educations.map((e) => e.toJson()).toList(),
          'skills': {
            'technicalSkills': _selectedTechnicalSkills,
            'softSkills': _selectedSoftSkills,
            'customSkills': _customSkills.map((e) => e.toJson()).toList(),
          },
          'jobPreferences': {
            'desiredRole': _desiredRoleController.text,
            'industryPreference': _industryPreferenceController.text,
            'jobType': _jobType,
            'salaryExpectation': _salaryExpectationController.text,
            'locationPreference': _locationPreferenceController.text,
          },
          'projects': _projects.map((e) => e.toJson()).toList(),
          'languages': _languages.map((e) => e.toJson()).toList(),
        };

        // Upload profile picture if changed
        String? profileImageUrl;
        if (_isProfileImageChanged && _profileImage != null) {
          profileImageUrl = await _uploadFile(
            _profileImage!,
            'profile_pictures/${FirebaseAuth.instance.currentUser!.uid}',
          );
          profileData['profileImageUrl'] = profileImageUrl;
        }

        // Upload resume if changed
        String? resumeUrl;
        if (_isResumeChanged && _resumeFile != null) {
          resumeUrl = await _uploadFile(
            _resumeFile!,
            'resumes/${FirebaseAuth.instance.currentUser!.uid}',
          );
          profileData['resumeUrl'] = resumeUrl;
        }

        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('JobSeekersProfiles')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .set(profileData, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error saving profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

// Initialize controller and form fields
  void _initFormFields() async {
    try {
      // Get user profile from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('JobSeekersProfiles')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        setState(() {
          // Personal Info
          if (data['personalInfo'] != null) {
            _nameController.text = data['personalInfo']['name'] ?? '';
            _titleController.text =
                data['personalInfo']['professionalTitle'] ?? '';
            _emailController.text = data['personalInfo']['email'] ?? '';
            _phoneController.text = data['personalInfo']['phone'] ?? '';
            _locationController.text = data['personalInfo']['location'] ?? '';
            _websiteController.text = data['personalInfo']['website'] ?? '';
          }

          // Professional Summary
          _summaryController.text = data['professionalSummary'] ?? '';

          // Work Experiences
          if (data['workExperiences'] != null) {
            _workExperiences = List<WorkExperience>.from(
              (data['workExperiences'] as List).map(
                (e) => WorkExperience.fromJson(e),
              ),
            );
          }

          // Educations
          if (data['educations'] != null) {
            _educations = List<Education>.from(
              (data['educations'] as List).map(
                (e) => Education.fromJson(e),
              ),
            );
          }

          // Skills
          if (data['skills'] != null) {
            if (data['skills']['technicalSkills'] != null) {
              _selectedTechnicalSkills =
                  List<String>.from(data['skills']['technicalSkills']);
            }
            if (data['skills']['softSkills'] != null) {
              _selectedSoftSkills =
                  List<String>.from(data['skills']['softSkills']);
            }
            if (data['skills']['customSkills'] != null) {
              _customSkills = List<CustomSkill>.from(
                (data['skills']['customSkills'] as List).map(
                  (e) => CustomSkill.fromJson(e),
                ),
              );
            }
          }

          // Job Preferences
          if (data['jobPreferences'] != null) {
            _desiredRoleController.text =
                data['jobPreferences']['desiredRole'] ?? '';
            _industryPreferenceController.text =
                data['jobPreferences']['industryPreference'] ?? '';
            _jobType = data['jobPreferences']['jobType'] ?? 'Full-time';
            _salaryExpectationController.text =
                data['jobPreferences']['salaryExpectation'] ?? '';
            _locationPreferenceController.text =
                data['jobPreferences']['locationPreference'] ?? '';
          }

          // Projects
          if (data['projects'] != null) {
            _projects = List<Project>.from(
              (data['projects'] as List).map(
                (e) => Project.fromJson(e),
              ),
            );
          }

          // Languages
          if (data['languages'] != null) {
            _languages = List<Language>.from(
              (data['languages'] as List).map(
                (e) => Language.fromJson(e),
              ),
            );
          }

          // Profile Image
          if (data['profileImageUrl'] != null) {
            _profileImageUrl = data['profileImageUrl'];
          }

          // Resume
          if (data['resumeUrl'] != null) {
            _resumeUrl = data['resumeUrl'];
          }
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

// Variables to be declared in your class
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

// Personal Information
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

// Professional Summary
  final TextEditingController _summaryController = TextEditingController();

// Job Preferences
  final TextEditingController _desiredRoleController = TextEditingController();
  final TextEditingController _industryPreferenceController =
      TextEditingController();
  String _jobType = 'Full-time';
  final TextEditingController _salaryExpectationController =
      TextEditingController();
  final TextEditingController _locationPreferenceController =
      TextEditingController();

// Work Experience
  List<WorkExperience> _workExperiences = [];

// Education
  List<Education> _educations = [];

// Skills
  List<String> _selectedTechnicalSkills = [];
  List<String> _selectedSoftSkills = [];
  List<CustomSkill> _customSkills = [];

// Projects
  List<Project> _projects = [];

// Languages
  List<Language> _languages = [];

// Files
  File? _profileImage;
  bool _isProfileImageChanged = false;
  String? _profileImageUrl;
  File? _resumeFile;
  bool _isResumeChanged = false;
  String? _resumeUrl;

// Loading state
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initFormFields();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _summaryController.dispose();
    _desiredRoleController.dispose();
    _industryPreferenceController.dispose();
    _salaryExpectationController.dispose();
    _locationPreferenceController.dispose();
    super.dispose();
  }

  // Navigate to Home Screen
  void _navigateToHomeScreen() {
    Navigator.pushReplacementNamed(context, '/HomeScreen');
  }
}

// Add these models to your class
class WorkExperience {
  String jobTitle;
  String company;
  String startDate;
  String endDate;
  String responsibilities;

  WorkExperience({
    this.jobTitle = '',
    this.company = '',
    this.startDate = '',
    this.endDate = '',
    this.responsibilities = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'jobTitle': jobTitle,
      'company': company,
      'startDate': startDate,
      'endDate': endDate,
      'responsibilities': responsibilities,
    };
  }

  factory WorkExperience.fromJson(Map<String, dynamic> json) {
    return WorkExperience(
      jobTitle: json['jobTitle'] ?? '',
      company: json['company'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      responsibilities: json['responsibilities'] ?? '',
    );
  }
}

class Education {
  String degree;
  String institution;
  String graduationYear;
  String certifications;

  Education({
    this.degree = '',
    this.institution = '',
    this.graduationYear = '',
    this.certifications = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'institution': institution,
      'graduationYear': graduationYear,
      'certifications': certifications,
    };
  }

  factory Education.fromJson(Map<String, dynamic> json) {
    return Education(
      degree: json['degree'] ?? '',
      institution: json['institution'] ?? '',
      graduationYear: json['graduationYear'] ?? '',
      certifications: json['certifications'] ?? '',
    );
  }
}

class CustomSkill {
  String name;
  String level;

  CustomSkill({
    this.name = '',
    this.level = 'Beginner',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
    };
  }

  factory CustomSkill.fromJson(Map<String, dynamic> json) {
    return CustomSkill(
      name: json['name'] ?? '',
      level: json['level'] ?? 'Beginner',
    );
  }
}

class Project {
  String name;
  String description;
  String role;
  String outcome;

  Project({
    this.name = '',
    this.description = '',
    this.role = '',
    this.outcome = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'role': role,
      'outcome': outcome,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      role: json['role'] ?? '',
      outcome: json['outcome'] ?? '',
    );
  }
}

class Language {
  String name;
  String proficiency;

  Language({
    this.name = '',
    this.proficiency = 'Basic',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'proficiency': proficiency,
    };
  }

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      name: json['name'] ?? '',
      proficiency: json['proficiency'] ?? 'Basic',
    );
  }
}
*/
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get screen height to make layout responsive
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Use Expanded with flex to distribute space proportionally
                Expanded(
                  flex: 2,
                  child: FadeInDown(
                    duration: Duration(milliseconds: 800),
                    child: _buildLogo(),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    delay: Duration(milliseconds: 300),
                    child: _buildWelcomeIllustration(),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    delay: Duration(milliseconds: 500),
                    child: _buildWelcomeText(),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInUp(
                        duration: Duration(milliseconds: 1000),
                        delay: Duration(milliseconds: 700),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        LoginScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(0.0, 0.2);
                                  var end = Offset.zero;
                                  var curve = Curves.easeOutQuint;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return SlideTransition(
                                      position: offsetAnimation, child: child);
                                },
                                transitionDuration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Sign In'),
                        ),
                      ),
                      SizedBox(height: 12),
                      FadeInUp(
                        duration: Duration(milliseconds: 1000),
                        delay: Duration(milliseconds: 800),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        RegisterScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  var begin = Offset(0.0, 0.2);
                                  var end = Offset.zero;
                                  var curve = Curves.easeOutQuint;
                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);
                                  return SlideTransition(
                                      position: offsetAnimation, child: child);
                                },
                                transitionDuration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Create Account'),
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
    );
  }

  Widget _buildLogo() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF1E3A8A).withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.work_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds);
            },
            child: Text(
              'SmartRecruit',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeIllustration() {
    return Container(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                'https://img.freepik.com/free-vector/business-team-discussing-ideas-startup_74855-4380.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF0D9488),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.business_center_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Discover Your Next Career Move',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            height: 1.2,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Connect with top companies and find your perfect job match with our AI-powered recruiting platform',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.of(context).pop();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Incorrect password.';
        } else {
          _errorMessage = 'Login failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    child: Container(
                      alignment: Alignment.center,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1E3A8A).withOpacity(0.3),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 200),
                    child: Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 300),
                    child: Text(
                      'Sign in to your account to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  if (_errorMessage.isNotEmpty) ...[
                    FadeIn(
                      duration: Duration(milliseconds: 400),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Color(0xFF1E3A8A)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A),
                        padding: EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Sign In',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterScreen()),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String _errorMessage = '';

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() {
        _emailSent = true;
      });
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No user found with this email.';
        } else {
          _errorMessage = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
        title: Text(
          'Forgot Password',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return FadeIn(
      duration: Duration(milliseconds: 500),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF0D9488),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Password Reset Email Sent',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'We\'ve sent a password reset link to:',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _emailController.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9488),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Text(
            'Please check your email and follow the instructions to reset your password.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1E3A8A),
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 40),
              elevation: 4,
              shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Back to Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeInDown(
            duration: Duration(milliseconds: 600),
            child: Container(
              alignment: Alignment.center,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          FadeInDown(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 200),
            child: Text(
              'Forgot Your Password?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: 16),
          FadeInDown(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 300),
            child: Text(
              'Enter your email address and we\'ll send you a link to reset your password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(height: 40),
          if (_errorMessage.isNotEmpty) ...[
            FadeIn(
              duration: Duration(milliseconds: 400),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color(0xFF64748B)),
                  prefixIcon:
                      Icon(Icons.email_outlined, color: Color(0xFF1E3A8A)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ),
          ),
          SizedBox(height: 32),
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 500),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1E3A8A),
                padding: EdgeInsets.symmetric(vertical: 18),
                elevation: 4,
                shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Reset Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      )),
            ),
          ),
          SizedBox(height: 24),
          FadeInUp(
            duration: Duration(milliseconds: 600),
            delay: Duration(milliseconds: 600),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Remember your password? ",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';
  String _userType = 'jobseeker';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Create initial user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'email': _emailController.text.trim(),
        'userType': _userType,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': _userType == 'recruiter' ? false : true,
      });

      // Navigate back to auth wrapper which will handle the routing
      Navigator.of(context).pop();
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists for this email.';
        } else {
          _errorMessage = 'Registration failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fixed sizes instead of percentage-based ones
    const double iconSize = 23.0;
    const double headerFontSize = 24.0;
    const double subtitleFontSize = 16.0;
    const double bodyFontSize = 16.0;
    const double verticalSpacing = 20.0;
    const double formPadding = 16.0;

    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E3A8A)),
        toolbarHeight: 56.0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Header Section
                  Container(
                    height: 130,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF1E3A8A).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                        ),
                        SizedBox(height: 11),
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          delay: Duration(milliseconds: 200),
                          child: Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        FadeInDown(
                          duration: Duration(milliseconds: 600),
                          delay: Duration(milliseconds: 300),
                          child: Text(
                            'Sign up to get started with SmartRecruit',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Type Selection
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 350),
                    child: Container(
                      margin: EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I am a:',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                                fontSize: bodyFontSize,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Job Seeker',
                                        style:
                                            TextStyle(fontSize: bodyFontSize)),
                                    value: 'jobseeker',
                                    groupValue: _userType,
                                    onChanged: (value) {
                                      setState(() {
                                        _userType = value!;
                                      });
                                    },
                                    activeColor: Color(0xFF0D9488),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text('Recruiter',
                                        style:
                                            TextStyle(fontSize: bodyFontSize)),
                                    value: 'recruiter',
                                    groupValue: _userType,
                                    onChanged: (value) {
                                      setState(() {
                                        _userType = value!;
                                      });
                                    },
                                    activeColor: Color(0xFF0D9488),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage.isNotEmpty) ...[
                    FadeIn(
                      duration: Duration(milliseconds: 400),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Color(0xFFB91C1C), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: bodyFontSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Email Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Color(0xFF1E3A8A), size: 22),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Password Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscurePassword,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Confirm Password Field
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: bodyFontSize,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1E3A8A), size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Color(0xFF64748B),
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(fontSize: bodyFontSize),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  // Create Account Button
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      margin: EdgeInsets.only(bottom: 15),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 23,
                                width: 23,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Create Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                )),
                      ),
                    ),
                  ),

                  // Sign In Link
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 16,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginScreen()),
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _businessIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyWebsiteController.dispose();
    _businessIdController.dispose();
    super.dispose();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('verificationRequests').add({
        'userId': user!.uid,
        'companyName': _companyNameController.text.trim(),
        'companyWebsite': _companyWebsiteController.text.trim(),
        'businessId': _businessIdController.text.trim(),
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'verificationRequestSubmitted': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification request submitted successfully!'),
          backgroundColor: Color(0xFF0D9488), // Teal
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting verification: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F5F9), // Lighter background
      appBar: AppBar(
        title: Text(
          'Recruiter Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF1E3A8A), // Navy blue
        automaticallyImplyLeading: false,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFE0F2F1), // Light teal background
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF0D9488)), // Teal
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your account requires verification to post jobs. Please provide your business details.',
                              style: TextStyle(
                                  color: Color(0xFF0D9488),
                                  fontWeight: FontWeight.w500), // Teal
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 200),
                    child: Text(
                      'Business Verification',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A), // Navy blue
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  FadeInDown(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 300),
                    child: Text(
                      'Please provide your business information for verification',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B), // Lighter text for subtitle
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _companyNameController,
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.business_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your company name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _companyWebsiteController,
                        decoration: InputDecoration(
                          labelText: 'Company Website',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.language_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your company website';
                          }
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'Website must start with http:// or https://';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 600),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _businessIdController,
                        decoration: InputDecoration(
                          labelText: 'Business ID / Registration Number',
                          labelStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.badge_outlined,
                              color: Color(0xFF1E3A8A)), // Navy
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your business ID';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 700),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A), // Navy blue
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: Color(0xFF1E3A8A).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16), // More rounded corners
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('Submit Verification',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 16),
                  FadeInUp(
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 800),
                    child: TextButton(
                      onPressed: () async {
                        await firebase_auth.FirebaseAuth.instance.signOut();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFF64748B),
                      ),
                      child: Text('Logout and Return Later'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Feature> _primaryFeatures = [];
  final List<Feature> _secondaryFeatures = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _animationController.forward();

    // Initialize features after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFeatures();
    });
  }

  void _initFeatures() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isRecruiter = userProvider.isRecruiter;

    // Clear existing features
    _primaryFeatures.clear();
    _secondaryFeatures.clear();

    if (isRecruiter) {
      // Primary features for recruiters
      _primaryFeatures.addAll([
        Feature(
          icon: Icons.post_add,
          title: 'Post Job',
          color: Color(0xFF0D9488),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DraftJobsScreen()),
            );
          },
        ),
        Feature(
          icon: Icons.description,
          title: 'My Jobs',
          color: Color(0xFF1E3A8A),
          onTap: () {
            Navigator.pushNamed(context, '/my-jobs');
          },
        ),
        Feature(
          icon: Icons.people,
          title: 'Candidates',
          color: Color(0xFF4F46E5),
          onTap: () {
            Navigator.pushNamed(context, '/candidates');
          },
        ),
        Feature(
          icon: Icons.event,
          title: 'Interviews',
          color: Color(0xFF0891B2),
          onTap: () {
            Navigator.pushNamed(context, '/interviews');
          },
        ),
      ]);

      // Secondary features for recruiters
      _secondaryFeatures.addAll([
        Feature(
          icon: Icons.question_answer,
          title: 'Interview Questions',
          color: Color(0xFF9333EA),
          onTap: () {
            Navigator.pushNamed(context, '/interview-questions');
          },
        ),
        Feature(
          icon: Icons.mail,
          title: 'Offers',
          color: Color(0xFFD97706),
          onTap: () {
            Navigator.pushNamed(context, '/offers');
          },
        ),
      ]);
    } else {
      // Primary features for job seekers
      _primaryFeatures.addAll([
        Feature(
          icon: Icons.search,
          title: 'Find Jobs',
          color: Color(0xFF1E3A8A),
          onTap: () {
            Navigator.pushNamed(context, '/find-jobs');
          },
        ),
        Feature(
          icon: Icons.person,
          title: 'My Profile',
          color: Color(0xFF0D9488),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JobseekerProfileForm()),
            );
          },
        ),
        Feature(
          icon: Icons.bookmark,
          title: 'Saved Jobs',
          color: Color(0xFF4F46E5),
          onTap: () {
            Navigator.pushNamed(context, '/saved-jobs');
          },
        ),
        Feature(
          icon: Icons.work,
          title: 'Applications',
          color: Color(0xFFD97706),
          onTap: () {
            Navigator.pushNamed(context, '/my-applications');
          },
        ),
      ]);

      // Secondary features for job seekers
      _secondaryFeatures.addAll([
        Feature(
          icon: Icons.upload_file,
          title: 'Resume',
          color: Color(0xFF9333EA),
          onTap: () {
            Navigator.pushNamed(context, '/resume-manager');
          },
        ),
        Feature(
          icon: Icons.event,
          title: 'Interviews',
          color: Color(0xFF0891B2),
          onTap: () {
            Navigator.pushNamed(context, '/my-interviews');
          },
        ),
        Feature(
          icon: Icons.mail,
          title: 'Offers',
          color: Color(0xFFEF4444),
          onTap: () {
            Navigator.pushNamed(context, '/my-offers');
          },
        ),
      ]);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isRecruiter = userProvider.isRecruiter;
    final userName = userProvider.userData?['name'] ?? 'User';

    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'SmartRecruit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          IconButton(
            icon: Icon(Icons.message_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/messages');
            },
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: CustomScrollView(
        slivers: [
          // Welcome Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Adjusted to avoid vertical overflow
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 32,
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min, // Keep column as small as needed
                      children: [
                        Text(
                          'Welcome, $userName!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          isRecruiter ? 'Recruiter' : 'Job Seeker',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Primary Features Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 4),
              child: Row(
                children: [
                  Text(
                    isRecruiter ? 'Recruitment Tools' : 'Job Search Tools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.grid_view_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Primary Features Grid - Fixed grid sizing
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2, // Increased for more height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        index * 0.1,
                        index * 0.1 + 0.4,
                        curve: Curves.easeOut,
                      ),
                    ),
                  );

                  return _buildAnimatedFeatureCard(
                    context,
                    _primaryFeatures[index],
                    animation,
                    isPrimary: true,
                  );
                },
                childCount: _primaryFeatures.length,
              ),
            ),
          ),

          // Secondary Features Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Additional Resources',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),

          // Secondary Features List
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        0.4 + index * 0.1,
                        0.4 + index * 0.1 + 0.4,
                        curve: Curves.easeOut,
                      ),
                    ),
                  );

                  return _buildAnimatedFeatureCard(
                    context,
                    _secondaryFeatures[index],
                    animation,
                    isPrimary: false,
                  );
                },
                childCount: _secondaryFeatures.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFeatureCard(
      BuildContext context, Feature feature, Animation<double> animation,
      {required bool isPrimary}) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: isPrimary
          ? _buildPrimaryFeatureCard(context, feature)
          : _buildSecondaryFeatureCard(context, feature),
    );
  }

  Widget _buildPrimaryFeatureCard(BuildContext context, Feature feature) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Use minimum space needed
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 28, // Slightly reduced
                ),
              ),
              SizedBox(height: 12), // Reduced spacing
              FittedBox(
                // Use FittedBox to prevent text overflow
                fit: BoxFit.scaleDown,
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 15, // Slightly reduced
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryFeatureCard(BuildContext context, Feature feature) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: 12), // Reduced padding
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10), // Reduced padding
                decoration: BoxDecoration(
                  color: feature.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 22, // Reduced size
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 15, // Reduced font size
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFD1D5DB),
                size: 14, // Reduced size
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simplified Feature class
class Feature {
  final IconData icon;
  final String title;
  final Color color;
  final Function() onTap;

  Feature({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

// Keeping the App Drawer class unchanged
class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isRecruiter = userProvider.isRecruiter;
    final userName = userProvider.userData?['name'] ?? 'User';
    final userEmail = userProvider.userData?['email'] ?? 'user@example.com';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: userProvider.userData?['profilePicture'] !=
                          null
                      ? NetworkImage(userProvider.userData!['profilePicture'])
                      : null,
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: userProvider.userData?['profilePicture'] == null
                      ? Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                ),
                SizedBox(height: 12),
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.home,
            title: 'Home',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          if (isRecruiter) ...[
            _buildDrawerItem(
              context,
              icon: Icons.post_add,
              title: 'Post New Job',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DraftJobsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.description,
              title: 'My Job Postings',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-jobs');
              },
            ),
            _buildDrawerItem(context,
                icon: Icons.people, title: 'Candidate Pool', onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CandidateMatchingScreen()),
              );
            }),
            _buildDrawerItem(
              context,
              icon: Icons.event,
              title: 'Interview Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/interviews');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.question_answer,
              title: 'Interview Questions',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AIInterviewQuestionsScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.mail,
              title: 'Offer Management',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OfferLetterAutomationScreen()),
                );
              },
            ),
          ] else ...[
            _buildDrawerItem(
              context,
              icon: Icons.search,
              title: 'Find Jobs',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/find-jobs');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.person,
              title: 'My Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => JobseekerProfileForm()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.upload_file,
              title: 'Resume Manager',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/resume-manager');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.bookmark,
              title: 'Saved Jobs',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/saved-jobs');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.work,
              title: 'My Applications',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-applications');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.event,
              title: 'My Interviews',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-interviews');
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.mail,
              title: 'My Offers',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/my-offers');
              },
            ),
          ],
          _buildDrawerItem(
            context,
            icon: Icons.message,
            title: 'Messages',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InAppChatScreen()),
              );
            },
          ),
          Divider(),
          _buildDrawerItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/help');
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              Navigator.pop(context);
              await firebase_auth.FirebaseAuth.instance.signOut();
              userProvider.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
      title: Text(title),
      onTap: onTap,
    );
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Account'),
          _buildSettingsItem(
            context,
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Update your profile details',
            onTap: () {
              // Navigate to profile edit
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.lock_outline,
            title: 'Password & Security',
            subtitle: 'Change password and security settings',
            onTap: () {
              // Navigate to security settings
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Manage your privacy settings',
            onTap: () {
              // Navigate to privacy settings
            },
          ),
          _buildSectionHeader('Appearance'),
          _buildSwitchItem(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            value: userProvider.isDarkMode,
            onChanged: (value) {
              userProvider.toggleDarkMode();
            },
          ),
          _buildSectionHeader('Notifications'),
          _buildSwitchItem(
            context,
            icon: Icons.notifications_none_outlined,
            title: 'Push Notifications',
            value: userProvider.enableNotifications,
            onChanged: (value) {
              userProvider.toggleNotifications();
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Manage email notification preferences',
            onTap: () {
              // Navigate to email notification settings
            },
          ),
          _buildSectionHeader('Preferences'),
          _buildSettingsItem(
            context,
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: userProvider.preferredLanguage,
            onTap: () {
              _showLanguageDialog(context);
            },
          ),
          _buildSectionHeader('Support'),
          _buildSettingsItem(
            context,
            icon: Icons.help_outline,
            title: 'Help Center',
            subtitle: 'Get help with using SmartRecruit',
            onTap: () {
              // Navigate to help center
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.contact_support_outlined,
            title: 'Contact Us',
            subtitle: 'Reach out to our support team',
            onTap: () {
              // Navigate to contact page
            },
          ),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App information and legal details',
            onTap: () {
              // Navigate to about page
            },
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () async {
                await firebase_auth.FirebaseAuth.instance.signOut();
                userProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF3F4F6),
                foregroundColor: Color(0xFF1F2937),
              ),
              child: Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final List<String> languages = [
      'English',
      'Spanish',
      'French',
      'German',
      'Chinese'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Language'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                return ListTile(
                  title: Text(language),
                  trailing: userProvider.preferredLanguage == language
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () {
                    userProvider.setPreferredLanguage(language);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

// Loading Screen
class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF1F5F9),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white,
                        size: 65,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 40),

              // App name with shadow
              Text(
                'SmartRecruit',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black12,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),

              // Tagline with faded background
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Finding your perfect match',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(height: 60),

              // Custom loading animation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor),
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Color(0xFF0D9488),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 40),

              // Loading text with fade animation
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(0.4, 1.0),
                ),
                child: Text(
                  'Loading your opportunities...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
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

class ResumeUploadScreen extends StatelessWidget {
  const ResumeUploadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/HomeScreen'),
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_ind, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Complete your profile for better job matches',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'A complete profile increases your chances of finding the perfect job by 70%',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'docx'],
                  );
                  if (result != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobseekerProfileForm(
                          resumeFile: File(result.files.single.path!),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Resume and Continue'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const JobseekerProfileForm()),
                  );
                },
                child: const Text('Fill Manually'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobseekerProfileForm extends StatefulWidget {
  final File? resumeFile;

  const JobseekerProfileForm({Key? key, this.resumeFile}) : super(key: key);

  @override
  State<JobseekerProfileForm> createState() => _JobseekerProfileFormState();
}

class _JobseekerProfileFormState extends State<JobseekerProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = firebase_auth.FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // User basic info controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();
  final TextEditingController _portfolioController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  // Skills and experience
  List<String> _technicalSkills = [];
  List<String> _softSkills = [];
  List<String> _languages = [];

  final List<String> _allTechnicalSkills = [
    'Flutter',
    'Firebase',
    'Dart',
    'Python',
    'Java',
    'React',
    'JavaScript',
    'SQL',
    'Node.js',
    'AWS',
    'Swift',
    'Kotlin',
    'C#',
    'HTML/CSS',
    'PHP',
    'Go',
    'Ruby',
    'TypeScript'
  ];

  final List<String> _allSoftSkills = [
    'Communication',
    'Teamwork',
    'Problem-solving',
    'Time management',
    'Leadership',
    'Adaptability',
    'Project management',
    'Critical thinking',
    'Conflict resolution',
    'Emotional intelligence',
    'Creativity'
  ];

  final List<String> _allLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Russian',
    'Arabic',
    'Portuguese',
    'Hindi',
    'Italian'
  ];

  // Education, work experience, projects and certificates
  List<Map<String, dynamic>> _educations = [];
  List<Map<String, dynamic>> _workExperiences = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _certificates = [];

  // Files
  File? _resumeFile;
  File? _profilePicFile;
  String? _resumeUrl;
  String? _profilePicUrl;

  bool _isLoading = true;
  bool _isSaving = false;
  int _currentStep = 0;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    _resumeFile = widget.resumeFile;

    // Set email from current user
    _emailController.text = _auth.currentUser?.email ?? '';

    _profileStream = _firestore
        .collection('JobSeekersProfiles')
        .doc(_auth.currentUser!.uid)
        .snapshots();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc =
          await _firestore.collection('JobSeekersProfiles').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        // Basic info
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _locationController.text = data['location'] ?? '';
        _linkedinController.text = data['linkedin'] ?? '';
        _githubController.text = data['github'] ?? '';
        _portfolioController.text = data['portfolio'] ?? '';
        _summaryController.text = data['summary'] ?? '';

        // Skills and languages
        _technicalSkills = List<String>.from(data['technicalSkills'] ?? []);
        _softSkills = List<String>.from(data['softSkills'] ?? []);
        _languages = List<String>.from(data['languages'] ?? []);

        // Education, experiences, projects and certificates
        _educations = List<Map<String, dynamic>>.from(data['educations'] ?? []);
        _workExperiences =
            List<Map<String, dynamic>>.from(data['workExperiences'] ?? []);
        _projects = List<Map<String, dynamic>>.from(data['projects'] ?? []);
        _certificates =
            List<Map<String, dynamic>>.from(data['certificates'] ?? []);

        // URLs
        _resumeUrl = data['resumeUrl'];
        _profilePicUrl = data['profilePicUrl'];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
    if (result != null) {
      setState(() => _resumeFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickProfilePic() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profilePicFile = File(picked.path));
    }
  }

  Future<String?> _uploadToSupabase(
      File file, String path, String? oldFileUrl) async {
    try {
      final fileName =
          '${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final fullPath = '$path/$fileName';

      // Delete old file if exists
      if (oldFileUrl != null && oldFileUrl.isNotEmpty) {
        try {
          final oldPath = oldFileUrl
              .split('/storage/v1/object/public/smartrecruitfiles/')
              .last;
          await _supabase.storage.from('smartrecruitfiles').remove([oldPath]);
        } catch (e) {
          debugPrint('Failed to delete old file: $e');
        }
      }

      // Upload new file
      await _supabase.storage
          .from('smartrecruitfiles')
          .upload(fullPath, file, fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('smartrecruitfiles').getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = _auth.currentUser!.uid;

      // Upload files if selected
      if (_resumeFile != null) {
        _resumeUrl =
            await _uploadToSupabase(_resumeFile!, 'resumes', _resumeUrl);
      }

      if (_profilePicFile != null) {
        _profilePicUrl = await _uploadToSupabase(
            _profilePicFile!, 'profile_pics', _profilePicUrl);
      }

      // Save all data to Firestore
      await _firestore.collection('JobSeekersProfiles').doc(uid).set({
        'userId': uid,
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'location': _locationController.text,
        'linkedin': _linkedinController.text,
        'github': _githubController.text,
        'portfolio': _portfolioController.text,
        'summary': _summaryController.text,
        'technicalSkills': _technicalSkills,
        'softSkills': _softSkills,
        'languages': _languages,
        'educations': _educations,
        'workExperiences': _workExperiences,
        'projects': _projects,
        'certificates': _certificates,
        'resumeUrl': _resumeUrl,
        'profilePicUrl': _profilePicUrl,
        'profileCompletionPercentage': _calculateProfileCompletion(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      // Navigate to Home screen
      Navigator.pushReplacementNamed(context, '/HomeScreen');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int _calculateProfileCompletion() {
    int total = 0;
    int completed = 0;

    // Basic info - 30%
    total += 6;
    if (_nameController.text.isNotEmpty) completed++;
    if (_emailController.text.isNotEmpty) completed++;
    if (_phoneController.text.isNotEmpty) completed++;
    if (_locationController.text.isNotEmpty) completed++;
    if (_summaryController.text.isNotEmpty) completed++;
    if (_profilePicUrl != null) completed++;

    // Resume - 10%
    total += 1;
    if (_resumeUrl != null) completed++;

    // Skills - 15%
    total += 3;
    if (_technicalSkills.isNotEmpty) completed++;
    if (_softSkills.isNotEmpty) completed++;
    if (_languages.isNotEmpty) completed++;

    // Experience and education - 45%
    total += 4;
    if (_educations.isNotEmpty) completed++;
    if (_workExperiences.isNotEmpty) completed++;
    if (_projects.isNotEmpty) completed++;
    if (_certificates.isNotEmpty) completed++;

    return ((completed / total) * 100).round();
  }

  void _addEducation() {
    showDialog(
      context: context,
      builder: (context) => _EducationDialog(
        onSave: (education) {
          setState(() => _educations.add(education));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editEducation(int index) {
    showDialog(
      context: context,
      builder: (context) => _EducationDialog(
        education: _educations[index],
        onSave: (education) {
          setState(() => _educations[index] = education);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addWorkExperience() {
    showDialog(
      context: context,
      builder: (context) => _WorkExperienceDialog(
        onSave: (experience) {
          setState(() => _workExperiences.add(experience));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editWorkExperience(int index) {
    showDialog(
      context: context,
      builder: (context) => _WorkExperienceDialog(
        experience: _workExperiences[index],
        onSave: (experience) {
          setState(() => _workExperiences[index] = experience);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addProject() {
    showDialog(
      context: context,
      builder: (context) => _ProjectDialog(
        onSave: (project) {
          setState(() => _projects.add(project));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editProject(int index) {
    showDialog(
      context: context,
      builder: (context) => _ProjectDialog(
        project: _projects[index],
        onSave: (project) {
          setState(() => _projects[index] = project);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _addCertificate() {
    showDialog(
      context: context,
      builder: (context) => _CertificateDialog(
        onSave: (certificate) {
          setState(() => _certificates.add(certificate));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editCertificate(int index) {
    showDialog(
      context: context,
      builder: (context) => _CertificateDialog(
        certificate: _certificates[index],
        onSave: (certificate) {
          setState(() => _certificates[index] = certificate);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickProfilePic,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profilePicFile != null
                        ? FileImage(_profilePicFile!) as ImageProvider
                        : _profilePicUrl != null
                            ? NetworkImage(_profilePicUrl!) as ImageProvider
                            : null,
                    child: (_profilePicFile == null && _profilePicUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email *',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            readOnly: true, // Email is already set and readonly
          ),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return value.length >= 10 ? null : 'Enter a valid phone number';
            },
          ),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location *',
              prefixIcon: Icon(Icons.location_on),
              hintText: 'City, State, Country',
            ),
            validator: (value) => value!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Social Media & Online Presence',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          TextFormField(
            controller: _linkedinController,
            decoration: const InputDecoration(
              labelText: 'LinkedIn Profile',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          TextFormField(
            controller: _githubController,
            decoration: const InputDecoration(
              labelText: 'GitHub Profile',
              prefixIcon: Icon(Icons.code),
            ),
          ),
          TextFormField(
            controller: _portfolioController,
            decoration: const InputDecoration(
              labelText: 'Portfolio Website',
              prefixIcon: Icon(Icons.web),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeAndSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professional Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _summaryController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            validator: (value) =>
                value!.isEmpty ? 'Please add a professional summary' : null,
          ),
          const SizedBox(height: 24),
          const Text(
            'Resume/CV',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickResume,
            icon: const Icon(Icons.upload_file),
            label: Text(_resumeFile != null || _resumeUrl != null
                ? 'Change Resume'
                : 'Upload Resume'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          if (_resumeFile != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(p.basename(_resumeFile!.path)),
                subtitle: const Text('New file to upload'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () => setState(() => _resumeFile = null),
                ),
              ),
            )
          else if (_resumeUrl != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Resume uploaded'),
                subtitle: const Text('Click to preview'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () => setState(() => _resumeUrl = null),
                ),
                onTap: () async {
                  // Implement preview functionality here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Resume preview not implemented')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Technical Skills',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTechnicalSkills.map((skill) {
              final isSelected = _technicalSkills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _technicalSkills.add(skill);
                    } else {
                      _technicalSkills.remove(skill);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Soft Skills',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSoftSkills.map((skill) {
              final isSelected = _softSkills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _softSkills.add(skill);
                    } else {
                      _softSkills.remove(skill);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Languages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allLanguages.map((language) {
              final isSelected = _languages.contains(language);
              return FilterChip(
                label: Text(language),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _languages.add(language);
                    } else {
                      _languages.remove(language);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Education',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                onPressed: _addEducation,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _educations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No education added yet. Tap "Add" to include your educational background.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _educations.length,
                  itemBuilder: (context, index) {
                    final education = _educations[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(education['school'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(education['degree'] ?? ''),
                            Text(
                                '${education['startDate']} - ${education['endDate']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editEducation(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _educations.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildWorkExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Work Experience',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                onPressed: _addWorkExperience,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _workExperiences.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No work experience added yet. Tap "Add" to include your professional experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _workExperiences.length,
                  itemBuilder: (context, index) {
                    final experience = _workExperiences[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(experience['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(experience['company'] ?? ''),
                            Text(
                                '${experience['startDate']} - ${experience['endDate']}'),
                            if (experience['description']?.isNotEmpty ?? false)
                              Text(
                                experience['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editWorkExperience(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _workExperiences.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildProjectsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Projects',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                onPressed: _addProject,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _projects.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No projects added yet. Tap "Add" to showcase your work and achievements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(project['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project['date'] ?? ''),
                            if (project['link']?.isNotEmpty ?? false)
                              Text('Link: ${project['link']}'),
                            if (project['description']?.isNotEmpty ?? false)
                              Text(
                                project['description'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editProject(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _projects.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCertificatesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Certificates & Achievements',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                onPressed: _addCertificate,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _certificates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No certificates added yet. Tap "Add" to include your certifications and achievements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _certificates.length,
                  itemBuilder: (context, index) {
                    final certificate = _certificates[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(certificate['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(certificate['issuer'] ?? ''),
                            Text('Issued: ${certificate['date']}'),
                            if (certificate['link']?.isNotEmpty ?? false)
                              Text('Link: ${certificate['link']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editCertificate(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _certificates.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final completionPercentage = _calculateProfileCompletion();
    final Color progressColor = completionPercentage < 50
        ? Colors.red
        : completionPercentage < 80
            ? Colors.orange
            : Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'Profile Completion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: CircularProgressIndicator(
                        value: completionPercentage / 100,
                        strokeWidth: 15,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    Text(
                      '$completionPercentage%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const Text(
            'Profile Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewItem(
                      'Basic Information',
                      _nameController.text.isNotEmpty
                          ? 'Complete'
                          : 'Incomplete'),
                  _buildReviewItem(
                      'Resume',
                      _resumeUrl != null || _resumeFile != null
                          ? 'Uploaded'
                          : 'Not uploaded'),
                  _buildReviewItem(
                      'Professional Summary',
                      _summaryController.text.isNotEmpty
                          ? 'Added'
                          : 'Not added'),
                  _buildReviewItem('Technical Skills',
                      '${_technicalSkills.length} selected'),
                  _buildReviewItem(
                      'Soft Skills', '${_softSkills.length} selected'),
                  _buildReviewItem(
                      'Languages', '${_languages.length} selected'),
                  _buildReviewItem(
                      'Education', '${_educations.length} entries'),
                  _buildReviewItem(
                      'Work Experience', '${_workExperiences.length} entries'),
                  _buildReviewItem('Projects', '${_projects.length} entries'),
                  _buildReviewItem(
                      'Certificates', '${_certificates.length} entries'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recommendations to improve your profile:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_resumeUrl == null && _resumeFile == null)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Upload your resume to improve job matching'),
                    ),
                  if (_summaryController.text.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add a professional summary to stand out'),
                    ),
                  if (_technicalSkills.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Select relevant technical skills to match with jobs'),
                    ),
                  if (_educations.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add your educational background'),
                    ),
                  if (_workExperiences.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Add your work experience to showcase your expertise'),
                    ),
                  if (_projects.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text(
                          'Add projects to demonstrate your practical skills'),
                    ),
                  if (_certificates.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.warning, color: Colors.orange),
                      title: Text('Add certifications to validate your skills'),
                    ),
                  if (completionPercentage >= 80)
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text(
                          'Your profile is looking great! Ready to find jobs.'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: value.contains('Not') ||
                          value.contains('0 ') ||
                          value == 'Incomplete'
                      ? Colors.red
                      : Colors.black)),
        ],
      ),
    );
  }

  List<Step> get _steps => [
        Step(
          title: const Text('Basic Info'),
          content: _buildBasicInfoStep(),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: const Text('Resume & Summary'),
          content: _buildResumeAndSummaryStep(),
          isActive: _currentStep >= 1,
        ),
        Step(
          title: const Text('Skills'),
          content: _buildSkillsStep(),
          isActive: _currentStep >= 2,
        ),
        Step(
          title: const Text('Education'),
          content: _buildEducationStep(),
          isActive: _currentStep >= 3,
        ),
        Step(
          title: const Text('Experience'),
          content: _buildWorkExperienceStep(),
          isActive: _currentStep >= 4,
        ),
        Step(
          title: const Text('Projects'),
          content: _buildProjectsStep(),
          isActive: _currentStep >= 5,
        ),
        Step(
          title: const Text('Certificates'),
          content: _buildCertificatesStep(),
          isActive: _currentStep >= 6,
        ),
        Step(
          title: const Text('Review'),
          content: _buildReviewStep(),
          isActive: _currentStep >= 7,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/HomeScreen'),
            child: const Text('Skip for now',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepTapped: (step) => setState(() => _currentStep = step),
                onStepContinue: () {
                  if (_currentStep < _steps.length - 1) {
                    setState(() => _currentStep += 1);
                  } else {
                    _submitForm();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                steps: _steps,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(_currentStep == _steps.length - 1
                              ? 'Submit'
                              : 'Continue'),
                        ),
                        const SizedBox(width: 12),
                        if (_currentStep > 0)
                          OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: _isSaving ? const LinearProgressIndicator() : null,
    );
  }
}

// Dialog widgets for adding/editing entries
class _EducationDialog extends StatefulWidget {
  final Map<String, dynamic>? education;
  final Function(Map<String, dynamic>) onSave;

  const _EducationDialog({
    Key? key,
    this.education,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_EducationDialog> createState() => _EducationDialogState();
}

class _EducationDialogState extends State<_EducationDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _degreeController = TextEditingController();
  final TextEditingController _fieldController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.education != null) {
      _schoolController.text = widget.education!['school'] ?? '';
      _degreeController.text = widget.education!['degree'] ?? '';
      _fieldController.text = widget.education!['field'] ?? '';
      _startDateController.text = widget.education!['startDate'] ?? '';
      _endDateController.text = widget.education!['endDate'] ?? '';
      _gpaController.text = widget.education!['gpa'] ?? '';
      _descriptionController.text = widget.education!['description'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.education == null ? 'Add Education' : 'Edit Education'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'School/University *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _degreeController,
                decoration: const InputDecoration(
                  labelText: 'Degree *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _fieldController,
                decoration: const InputDecoration(
                  labelText: 'Field of Study *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Start Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _endDateController,
                decoration: const InputDecoration(
                  labelText: 'End Date *',
                  hintText: 'MM/YYYY or Present',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _gpaController,
                decoration: const InputDecoration(
                  labelText: 'GPA',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'school': _schoolController.text,
                'degree': _degreeController.text,
                'field': _fieldController.text,
                'startDate': _startDateController.text,
                'endDate': _endDateController.text,
                'gpa': _gpaController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WorkExperienceDialog extends StatefulWidget {
  final Map<String, dynamic>? experience;
  final Function(Map<String, dynamic>) onSave;

  const _WorkExperienceDialog({
    Key? key,
    this.experience,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_WorkExperienceDialog> createState() => _WorkExperienceDialogState();
}

class _WorkExperienceDialogState extends State<_WorkExperienceDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _currentlyWorking = false;

  @override
  void initState() {
    super.initState();
    if (widget.experience != null) {
      _titleController.text = widget.experience!['title'] ?? '';
      _companyController.text = widget.experience!['company'] ?? '';
      _locationController.text = widget.experience!['location'] ?? '';
      _startDateController.text = widget.experience!['startDate'] ?? '';
      _endDateController.text = widget.experience!['endDate'] ?? '';
      _descriptionController.text = widget.experience!['description'] ?? '';
      _currentlyWorking = widget.experience!['endDate'] == 'Present';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.experience == null
          ? 'Add Work Experience'
          : 'Edit Work Experience'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'City, Country',
                ),
              ),
              TextFormField(
                controller: _startDateController,
                decoration: const InputDecoration(
                  labelText: 'Start Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              CheckboxListTile(
                title: const Text('I currently work here'),
                value: _currentlyWorking,
                onChanged: (value) {
                  setState(() {
                    _currentlyWorking = value!;
                    if (_currentlyWorking) {
                      _endDateController.text = 'Present';
                    } else {
                      _endDateController.text = '';
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!_currentlyWorking)
                TextFormField(
                  controller: _endDateController,
                  decoration: const InputDecoration(
                    labelText: 'End Date *',
                    hintText: 'MM/YYYY',
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Responsibilities, achievements, etc.',
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'title': _titleController.text,
                'company': _companyController.text,
                'location': _locationController.text,
                'startDate': _startDateController.text,
                'endDate': _endDateController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectDialog extends StatefulWidget {
  final Map<String, dynamic>? project;
  final Function(Map<String, dynamic>) onSave;

  const _ProjectDialog({
    Key? key,
    this.project,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _titleController.text = widget.project!['title'] ?? '';
      _dateController.text = widget.project!['date'] ?? '';
      _linkController.text = widget.project!['link'] ?? '';
      _descriptionController.text = widget.project!['description'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Add Project' : 'Edit Project'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Project Title *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  hintText: 'MM/YYYY or date range',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Project Link',
                  hintText: 'GitHub, live demo, etc.',
                ),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Technologies used, your role, achievements, etc.',
                ),
                maxLines: 5,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'title': _titleController.text,
                'date': _dateController.text,
                'link': _linkController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CertificateDialog extends StatefulWidget {
  final Map<String, dynamic>? certificate;
  final Function(Map<String, dynamic>) onSave;

  const _CertificateDialog({
    Key? key,
    this.certificate,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<_CertificateDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _issuerController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _credentialIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.certificate != null) {
      _nameController.text = widget.certificate!['name'] ?? '';
      _issuerController.text = widget.certificate!['issuer'] ?? '';
      _dateController.text = widget.certificate!['date'] ?? '';
      _linkController.text = widget.certificate!['link'] ?? '';
      _credentialIdController.text = widget.certificate!['credentialId'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.certificate == null ? 'Add Certificate' : 'Edit Certificate'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Certificate Name *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Issuing Organization *',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Issue Date *',
                  hintText: 'MM/YYYY',
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _credentialIdController,
                decoration: const InputDecoration(
                  labelText: 'Credential ID',
                ),
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Certificate URL',
                  hintText: 'Verification link',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'name': _nameController.text,
                'issuer': _issuerController.text,
                'date': _dateController.text,
                'link': _linkController.text,
                'credentialId': _credentialIdController.text,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
