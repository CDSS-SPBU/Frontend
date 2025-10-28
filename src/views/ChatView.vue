<template>
  <ul id="msg-feed">
    <li v-for="msg in hist" :key="msg.timestamp">
      <p v-if="msg.role === 'user'" class="msg-usr">{{ msg.content }}</p>
      <p v-else-if="msg.role === 'bot'" class="msg-bot">{{ msg.content }}</p>
    </li>
  </ul>
  <textarea id="inp-qry" placeholder="Введите запрос" v-model="qry"></textarea>
  <button id="inp-btn" type="button" @click="sendMessage">
    <svg fill="lightgreen" view-box="0 0 20 22">
      <path d="M0,0V22L19.05,11L0,0"></path>
    </svg>
  </button>
</template>

<script>
/* eslint-disable */

export default {
  name: "ChatView",
  props: {
    wbs: WebSocket,
  },
  data: function () {
    return {
      hist: [
        /*{ role: "user", content: "short", timestamp: "1" },
        { role: "bot", content: "short2", timestamp: "2" },
        {
          role: "user",
          content: "I suppose this is medium length.",
          timestamp: "3",
        },
        {
          role: "bot",
          content: "I suppose this is medium length. Part 2.",
          timestamp: "4",
        },
        {
          role: "user",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say.",
          timestamp: "5",
        },
        {
          role: "bot",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say. **Version with extra flair**",
          timestamp: "6",
        },
        {
          role: "user",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say.",
          timestamp: "7",
        },
        {
          role: "bot",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say. **Version with extra flair**",
          timestamp: "8",
        },
        {
          role: "user",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say.",
          timestamp: "9",
        },
        {
          role: "bot",
          content:
            "The message presented is something I personally would classify as extensive. It is also worth noting that typing this is time-consuming. That is all I wanted to say. **Version with extra flair**",
          timestamp: "10",
        },*/
      ],
      qry: null,
    };
  },
  created: function () {
    if (this.wbs) {
      this.wbs.send(JSON.stringify({ type: "history" }));
      this.connection.onmessage = function (message) {
        const msg = JSON.parse(message);
        if (msg.type === "history") {
          hist = msg.messages;
        } else if (msg.type === "chat_message") {
          hist.push({ role: msg.role, content: msg.content, timestamp: "" }); //timestamps must be unique.
        }
      };
    }
  },
  methods: {
    sendMessage() {
      if (this.wbs) {
        this.wbs.send(
          JSON.stringify({ type: "chat_message", query: this.qry })
        );
      }
      this.qry = null;
    },
  },
};
</script>
