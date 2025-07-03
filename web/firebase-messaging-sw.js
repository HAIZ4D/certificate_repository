// Import and initialize the Firebase SDK
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing the generated config
const firebaseConfig = {
  apiKey: "AIzaSyBOC92kC8R8Irojea4IGTW8yA71bzfP6aA",
  authDomain: "mobile-project-63d46.firebaseapp.com",
  projectId: "mobile-project-63d46",
  storageBucket: "mobile-project-63d46.firebasestorage.app",
  messagingSenderId: "816767361642",
  appId: "1:816767361642:web:d18b39e3e3b18004e66013",
  measurementId: "G-H3NV75DTBT"
};

firebase.initializeApp(firebaseConfig);

// Retrieve firebase messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
}); 