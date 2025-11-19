<script>
import DocList from "./components/DocList.vue";
import CreateDoc from "./components/CreateDoc.vue";
import ChatFiller from "./components/ChatFiller.vue";

export default {
  name: "App",
  components: {
    DocList,
    CreateDoc,
    ChatFiller,
  },
  data: function () {
    // Переменные компонента
    return {
      connection: null,
      hist: [],
      activeComp: "",
      qry: null,
      defurl: "//localhost:8002",
    };
  },
  methods: {
    onop() {
      console.log("Подключение установлено.");
    },
    recMessage(message) {
      const data = JSON.parse(message.data);
      if (data.type === "history") {
        this.hist = data.messages;
      } else if (data.type === "chat_message") {
        this.hist.push({
          role: data.role,
          content: data.content,
          timestamp: Date(),
        });
      }
    },
    sendMessage() {
      if (this.qry) {
        this.connection.send(
          JSON.stringify({ type: "chat_message", query: this.qry })
        );
        this.hist.push({
          role: "user",
          content: this.qry,
          timestamp: Date(),
        });
        this.qry = null;
      }
    },
  },
  created: function () {
    console.log("Подключение...");
    this.connection = new WebSocket("ws:" + this.defurl + "/ws/chat");
    this.connection.onopen = this.onop;
    this.connection.onmessage = this.recMessage;
  },
};
</script>

<template>
  <div id="btnbox">
    <button type="button" @click="activeComp = 'ChatFiller'">Чат</button>
    <button type="button" @click="activeComp = 'DocList'">
      Список документов
    </button>
    <button type="button" @click="activeComp = 'CreateDoc'">
      Добавить документ
    </button>
  </div>
  <component :is="activeComp" :du="defurl"></component>
  <div v-if="activeComp === 'ChatFiller'">
    <ul class="feed" id="msg-feed">
      <li v-for="msg in hist" :key="msg.timestamp">
        <p v-if="msg.role === 'user'" class="msg-usr">{{ msg.content }}</p>
        <p v-else-if="msg.role === 'bot'" class="msg-bot">{{ msg.content }}</p>
      </li>
    </ul>
    <div id="input">
      <textarea placeholder="Введите запрос" v-model="qry"></textarea>
      <button type="button" @click="sendMessage">
        <svg fill="lightgreen" view-box="0 0 20 22">
          <path d="M0,0V22L19.05,11Z"></path>
        </svg>
      </button>
    </div>
  </div>
</template>
