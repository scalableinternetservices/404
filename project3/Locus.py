"""
Locust load test for chat-backend-rails application.

User personas:
1. New user registering for the first time (1 in every 10 users)
2. Polling user that checks for updates every 5 seconds
3. Active user that uses existing usernames to create conversations, post messages, and browse
"""

import os
import random
import threading
from datetime import datetime
from locust import HttpUser, task, between


# Configuration
MAX_USERS = 10000

class UserNameGenerator:
    PRIME_NUMBERS = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]

    def __init__(self, max_users=MAX_USERS, seed=None, prime_number=None):
        self.seed = seed or random.randint(0, max_users)
        self.prime_number = prime_number or random.choice(self.PRIME_NUMBERS)
        self.current_index = -1
        self.max_users = max_users
    
    def generate_username(self):
        self.current_index += 1
        return f"user_{(self.seed + self.current_index * self.prime_number) % self.max_users}"


class UserStore:
    def __init__(self):
        self.used_usernames = {}
        self.username_lock = threading.Lock()
        self.conversations = []  # shared list of conversation ids
        self.conversation_lock = threading.Lock()

    def get_random_user(self):
        with self.username_lock:
            random_username = random.choice(list(self.used_usernames.keys()))
            return self.used_usernames[random_username]

    def store_user(self, username, auth_token, user_id):
        with self.username_lock:
            self.used_usernames[username] = {
                "username": username,
                "auth_token": auth_token,
                "user_id": user_id
            }
            return self.used_usernames[username]

    def add_conversation(self, conversation_id):
        with self.conversation_lock:
            self.conversations.append(conversation_id)

    def get_random_conversation(self):
        with self.conversation_lock:
            if not self.conversations:
                return None
            return random.choice(self.conversations)


user_store = UserStore()
user_name_generator = UserNameGenerator(max_users=MAX_USERS)

class ChatBackend():
    """
    Base class for all user personas.
    Provides common authentication and API interaction methods.
    """        
    
    def login(self, username, password):
        """Login an existing user."""
        response = self.client.post(
            "/auth/login",
            json={"username": username, "password": password},
            name="/auth/login"
        )
        if response.status_code == 200:
            data = response.json()
            return user_store.store_user(username, data.get("token"), data.get("user", {}).get("id"))
        return None
        
    def register(self, username, password):
        response = self.client.post(
            "/auth/register",
            json={"username": username, "password": password},
            name="/auth/register"
        )
        if response.status_code in (200, 201):
            data = response.json()
            return user_store.store_user(username, data.get("token"), data.get("user", {}).get("id"))
        return None

    def auth_headers(self, token):
        if not token:
            return {}
        return {"Authorization": f"Bearer {token}"}

    def create_conversation(self, user):
        title = f"Conversation {random.randint(1, 1_000_000)}"
        response = self.client.post(
            "/conversations",
            json={"title": title},
            headers=self.auth_headers(user.get("auth_token")),
            name="/conversations#create"
        )
        if response.status_code in (200, 201):
            data = response.json()
            cid = data.get("id")
            if cid:
                user_store.add_conversation(cid)
            return True
        return False

    def send_message(self, user, conversation_id):
        if not conversation_id:
            return False
        content = f"msg-{random.randint(1, 1_000_000)}"
        response = self.client.post(
            "/messages",
            json={"conversationId": str(conversation_id), "content": content},
            headers=self.auth_headers(user.get("auth_token")),
            name="/messages#create"
        )
        return response.status_code in (200, 201)

    def check_conversation_updates(self, user):
        """Check for conversation updates."""
        params = {"userId": user.get("user_id")}
        if self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        
        response = self.client.get(
            "/api/conversations/updates",
            params=params,
            headers=self.auth_headers(user.get("auth_token")),
            name="/api/conversations/updates"
        )
        
        return response.status_code == 200
    
    def check_message_updates(self, user):
        params = {"userId": user.get("user_id")}
        if self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        response = self.client.get(
            "/api/messages/updates",
            params=params,
            headers=self.auth_headers(user.get("auth_token")),
            name="/api/messages/updates"
        )
        return response.status_code == 200
    
    def check_expert_queue_updates(self, user):
        params = {"expertId": user.get("user_id")}
        if self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        response = self.client.get(
            "/api/expert-queue/updates",
            params=params,
            headers=self.auth_headers(user.get("auth_token")),
            name="/api/expert-queue/updates"
        )
        return response.status_code == 200
    

class IdleUser(HttpUser, ChatBackend):
    """
    Persona: A user that logs in and is idle but their browser polls for updates.
    Checks for message updates, conversation updates, and expert queue updates every 5 seconds.
    """
    weight = 10
    wait_time = between(5, 5)  # Check every 5 seconds

    def on_start(self):
        """Called when a simulated user starts."""
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        if not self.user:
            raise Exception(f"Failed to login or register user {username}")

    @task
    def poll_for_updates(self):
        """Poll for all types of updates."""
        # Check conversation updates
        self.check_conversation_updates(self.user)
        
        # Check message updates
        self.check_message_updates(self.user)
        
        # Check expert queue updates
        self.check_expert_queue_updates(self.user)
        
        # Update last check time
        self.last_check_time = datetime.utcnow()


class ActiveUser(HttpUser, ChatBackend):
    """Persona: Actively creates conversations and sends messages, plus polls updates."""
    weight = 5
    wait_time = between(1, 3)

    def on_start(self):
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        if not self.user:
            raise Exception(f"Failed to init active user {username}")
        # Optionally seed a conversation
        self.create_conversation(self.user)

    @task(3)
    def send_message_task(self):
        convo = user_store.get_random_conversation()
        if convo:
            self.send_message(self.user, convo)
        else:
            # If no conversation exists, create one
            self.create_conversation(self.user)

    @task(1)
    def create_conversation_task(self):
        # Controlled creation probability via env var
        prob = float(os.getenv("LOCUST_CONVERSATION_CREATE_PROB", "0.3"))
        if random.random() < prob:
            self.create_conversation(self.user)

    @task(2)
    def poll_updates_task(self):
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.check_expert_queue_updates(self.user)
        self.last_check_time = datetime.utcnow()


class NewUser(HttpUser, ChatBackend):
    """Persona: Primarily registration and a single conversation/message."""
    weight = 1
    wait_time = between(10, 20)

    def on_start(self):
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.register(username, password)
        if not self.user:
            # Fallback attempt login in case race caused existing username
            self.user = self.login(username, password)
        if not self.user:
            raise Exception("Registration/Login failed for new user persona")
        # Immediately create a conversation and send one message
        if self.create_conversation(self.user):
            convo = user_store.get_random_conversation()
            self.send_message(self.user, convo)

    @task
    def occasional_poll(self):
        # Lower intensity polling
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.last_check_time = datetime.utcnow()


# Guidance:
# Run with: locust -f Locus.py --host https://YOUR_ENV.elasticbeanstalk.com --users 500 --spawn-rate 1
# Adjust persona weights above to mirror target distribution.
# Use environment variables to tweak creation probability:
#   LOCUST_CONVERSATION_CREATE_PROB=0.2 locust -f Locus.py ...