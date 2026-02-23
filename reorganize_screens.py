import os
import re

base_dir = r"d:\Hfidz\APP\E-Learning\lib"
screens_dir = os.path.join(base_dir, "screens")
package_name = "e_learning_app"

folders = {
    "admin": [
        "admin_assign_teacher.dart", "admin_course_detail.dart", "admin_course_management.dart",
        "admin_dashboard.dart", "admin_major_management.dart", "admin_user_management.dart"
    ],
    "teacher": [
        "teacher_assignment_detail.dart", "teacher_attendance_qr.dart", "teacher_class_detail.dart",
        "teacher_classes_screen.dart", "teacher_dashboard.dart", "teacher_grades_screen.dart"
    ],
    "student": [
        "student_course_detail.dart", "student_dashboard.dart", "student_enrolled_courses.dart",
        "student_grades_screen.dart", "student_home_view.dart", "student_krs.dart", "student_scanner.dart"
    ],
    "auth": [
        "login_screen.dart", "role_selection_dialog.dart", "select_major_screen.dart", "splash_screen.dart"
    ],
    "common": [
        "profile_settings_screen.dart", "user_calendar_view.dart"
    ]
}

# Move files
file_to_folder = {}
for folder, files in folders.items():
    folder_path = os.path.join(screens_dir, folder)
    os.makedirs(folder_path, exist_ok=True)
    for f in files:
        file_to_folder[f] = folder
        old_path = os.path.join(screens_dir, f)
        new_path = os.path.join(folder_path, f)
        if os.path.exists(old_path):
            os.rename(old_path, new_path)
            print(f"Moved {f} to {folder}/")

# Update imports
for root, _, files in os.walk(base_dir):
    for filename in files:
        if filename.endswith(".dart"):
            filepath = os.path.join(root, filename)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
            
            new_content = content
            for f, folder in file_to_folder.items():
                # Find import lines that end with the filename f
                # e.g., import '../screens/admin_dashboard.dart';
                # e.g., import 'admin_dashboard.dart';
                # e.g., import 'package:e_learning_app/screens/admin_dashboard.dart';
                
                # Regex breakdown:
                # import\s+['"]         -> `import '` or `import "`
                # ([^'"]*)              -> followed by any characters except quote (the path)
                # re.escape(f)          -> the filename exactly
                # ['"]                  -> closing quote
                
                pattern = r'(import\s+[\'"])([^\'"]*?)(' + re.escape(f) + r')([\'"])'
                
                def repl(match):
                    # Replace with the absolute package path
                    return match.group(1) + f"package:{package_name}/screens/{folder}/{f}" + match.group(4)
                
                new_content = re.sub(pattern, repl, new_content)
                
            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as file:
                    file.write(new_content)
                print(f"Updated imports in {os.path.relpath(filepath, base_dir)}")
