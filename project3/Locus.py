"""
Locust load test for chat-backend-rails application.

User personas:
1. New user registering for the first time (1 in every 10 users)
2. Polling user that checks for updates every 5 seconds
3. Active user that uses existing usernames to create conversations, post messages, and browse
4. Expert user that polls expert queue, claims unassigned conversations, and responds to assigned conversations
"""

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


user_store = UserStore()
user_name_generator = UserNameGenerator(max_users=MAX_USERS)


class ChatBackend():
    """
    Base class for all user personas.
    Provides common authentication and API interaction methods.
    """

    def auth_headers(self, token):
        if not token:
            return {}
        return { "Authorization": f"Bearer {token}" }

    def login(self, username, password):
        response = self.client.post(
            "/auth/login",
            json={"username": username, "password": password},
            name="/auth/login"
        )
        if response.status_code == 200:
            data = response.json()
            return user_store.store_user(username, data.get("token"), data.get("user", {}).get("id")
            )
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
    

    def check_conversation_updates(self, user):
        params = {"userId": user.get("user_id")}
        if self.last_check_time:
            params["since"] = self.last_check_time.isoformat()
        
        r = self.client.get(
            "/api/conversations/updates",
            params=params,
            headers=self.auth_headers(user["auth_token"]),
            name="/api/conversations/updates"
        )

        return r.status_code == 200

    def check_message_updates(self, user):
        params = {"userId": user.get("user_id")}
        if self.last_check_time:
            params["since"] = self.last_check_time.isoformat()

        r = self.client.get(
            "/api/messages/updates",
            params=params,
            headers=self.auth_headers(user["auth_token"]),
            name="/api/messages/updates"
        )
        return r.status_code == 200

    def check_expert_queue_updates(self, user):
        params = {"expertId": user.get("user_id")}
        r = self.client.get(
            "/api/expert-queue/updates",
            params=params,
            headers=self.auth_headers(user.get("auth_token")),
            name="/api/expert-queue/updates"
        )
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list) and len(data) > 0:
                obj = data[0]
                return (
                    obj.get("waitingConversations", []),
                    obj.get("assignedConversations", [])
                )
        return ([], [])

    def create_conversation(self, user):
        title = f"Conversation {random.randint(1, 1_000_000)}"
        r = self.client.post(
            "/conversations",
            json={"title": title},
            headers=self.auth_headers(user["auth_token"]),
            name="/conversations#create"
        )
        if r.status_code in (200, 201):
            data = r.json()
            cid = data.get("id")
            return cid
        return None

    def send_message(self, user, convo_id):
        content = f"msg-{random.randint(1, 1_000_000)}"
        r = self.client.post(
            f"/messages",
            json={"conversationId": str(convo_id), "content": content},
            headers=self.auth_headers(user["auth_token"]),
            name="/messages#create"
        )
        return r.status_code in (200, 201)

    def claim_conversation(self, user, convo_id):
        return self.client.post(
            f"/expert/conversations/{convo_id}/claim",
            headers=self.auth_headers(user["auth_token"]),
            name="/expert/claim"
        )


class IdleUser(HttpUser, ChatBackend):
    """
    Persona: A user that logs in and is idle but their browser polls for updates.
    Checks for message updates, conversation updates, and expert queue updates every 5 seconds.
    """
    weight = 10
    wait_time = between(5, 5)

    def on_start(self):
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        if not self.user:
            raise Exception(f"Failed login/register {username}")

    @task
    def poll_for_updates(self):
        self.check_conversation_updates(self.user)
        self.check_message_updates(self.user)
        self.check_expert_queue_updates(self.user)
        self.last_check_time = datetime.utcnow()


class ActiveUser(HttpUser, ChatBackend):
    """
    Persona: Users that actively create conversations and send messages.
    """
    weight = 30
    wait_time = between(2, 5)

    def on_start(self):
        self.last_check_time = None
        username = user_name_generator.generate_username()
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        self.my_conversations = []

    @task(2)
    def create_convo(self):
        convo = self.create_conversation(self.user)
        if convo:
            self.my_conversations.append(convo)

    @task(5)
    def send_message_task(self):
        if not self.my_conversations:
            return
        convo = random.choice(self.my_conversations)
        self.send_message(self.user, convo)

    @task(1)
    def poll(self):
        self.check_conversation_updates(self.user)
        self.last_check_time = datetime.utcnow()


class ExpertUser(HttpUser, ChatBackend):
    """
    Persona: Experts poll waiting conversations, claim some,
    and send messages to conversations they have claimed.
    """
    weight = 10
    wait_time = between(3, 7)

    def on_start(self):
        self.last_check_time = None
        username = f"expert_{user_name_generator.generate_username()}"
        password = username
        self.user = self.login(username, password) or self.register(username, password)
        self.claimed = []

    @task(3)
    def poll_queue(self):
        waiting, assigned = self.check_expert_queue_updates(self.user)
        self.last_check_time = datetime.utcnow()

        self.claimed = [c["id"] for c in assigned]

        if waiting and random.random() < 0.3:
            convo = random.choice(waiting)
            r = self.claim_conversation(self.user, convo["id"])
            if r.status_code == 200:
                self.claimed.append(convo["id"])

    @task(5)
    def respond(self):
        if not self.claimed:
            return
        convo = random.choice(self.claimed)
        self.send_message(self.user, convo)

    @task(1)
    def poll_convos(self):
        self.check_conversation_updates(self.user)
        self.last_check_time = datetime.utcnow()