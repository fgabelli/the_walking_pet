import 'package:flutter/material.dart';

class TutorialKeys {
  // ── Bottom Navigation Tabs ──
  static final GlobalKey socialTabKey = GlobalKey(debugLabel: 'socialTab');
  static final GlobalKey mapTabKey = GlobalKey(debugLabel: 'mapTab');
  static final GlobalKey datingTabKey = GlobalKey(debugLabel: 'datingTab');
  static final GlobalKey chatTabKey = GlobalKey(debugLabel: 'chatTab');
  static final GlobalKey profileTabKey = GlobalKey(debugLabel: 'profileTab');

  // ── Social / Community Screen ──
  static final GlobalKey createPostKey = GlobalKey(debugLabel: 'createPost');
  static final GlobalKey feedTabKey = GlobalKey(debugLabel: 'feedTab');
  static final GlobalKey reelsTabKey = GlobalKey(debugLabel: 'reelsTab');
  static final GlobalKey bachecaTabKey = GlobalKey(debugLabel: 'bachecaTab');

  // ── Map Screen ──
  static final GlobalKey mapFilterKey = GlobalKey(debugLabel: 'mapFilter');
  static final GlobalKey mapVisibilityKey = GlobalKey(debugLabel: 'mapVisibility');
  static final GlobalKey mapStartWalkKey = GlobalKey(debugLabel: 'mapStartWalk');
  static final GlobalKey mapSafetyFabKey = GlobalKey(debugLabel: 'mapSafetyFab');
  static final GlobalKey notificationTabKey = GlobalKey(debugLabel: 'notificationTab');
  static final GlobalKey activitiesFabKey = GlobalKey(debugLabel: 'activitiesFab');
  static final GlobalKey recenterFabKey = GlobalKey(debugLabel: 'recenterFab');

  // ── Profile Screen ──
  static final GlobalKey addPetKey = GlobalKey(debugLabel: 'addPet');
  static final GlobalKey businessProfileKey = GlobalKey(debugLabel: 'businessProfile');
}
