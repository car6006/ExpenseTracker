# Project Blueprint: AI-Powered Expense Tracker

## Overview

This document outlines the design, features, and development plan for the AI-Powered Expense Tracker application. The goal of this project is to create a modern, intuitive, and intelligent expense tracking application that leverages the power of generative AI to simplify and automate the process of tracking expenses.

## Existing Features

*   **Receipt Scanner:** The application allows users to scan receipts using their device's camera. The text from the receipt is extracted using Google's ML Kit.
*   **Theme Toggle:** The application supports both light and dark themes, and users can toggle between them or use the system's theme.
*   **Extracted Text Display:** The extracted text from the receipt is displayed on the home screen.

## Development Plan

### 1. Firebase Integration

*   **Goal:** Persist expense data to the cloud using Firestore.
*   **Steps:**
    1.  Add the `cloud_firestore` package to the `pubspec.yaml` file.
    2.  Initialize Firebase in the `main.dart` file.
    3.  Create a `FirebaseService` class to handle all interactions with Firestore.
    4.  Create a form to allow users to manually enter or edit the extracted information before saving it to Firestore.
    5.  Display a list of expenses on the home screen.

### 2. Generative AI for Expense Categorization

*   **Goal:** Automatically categorize expenses based on the extracted text from the receipt.
*   **Steps:**
    1.  Add the `google_generative_ai` package to the `pubspec.yaml` file.
    2.  Create a `GenerativeAIService` class to handle all interactions with the Gemini API.
    3.  Create a function to generate a category for a given expense based on its description.
    4.  Add a new field to the expense model to store the category.

### 3. Data Visualization

*   **Goal:** Visualize the user's expenses with a chart.
*   **Steps:**
    1.  Add the `fl_chart` package to the `pubspec.yaml` file.
    2.  Create a chart widget to display the user's expenses.
    3.  Add the chart to the home screen.

### 4. User Authentication

*   **Goal:** Allow users to have their own private expense data.
*   **Steps:**
    1.  Add the `firebase_auth` package to the `pubspec.yaml` file.
    2.  Create a `FirebaseAuthenticationService` class to handle user sign-up and sign-in.
    3.  Create a login screen and a sign-up screen.
    4.  Protect the user's expense data by adding security rules to Firestore.

### 5. Enhanced UI/UX

*   **Goal:** Improve the user interface and user experience.
*   **Steps:**
    1.  Add icons for different expense categories.
    2.  Add animations to make the app more engaging.
    3.  Improve the layout of the expense list to make it more readable.
