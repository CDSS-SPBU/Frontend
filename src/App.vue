<template>
  <div id="btnbox">
    <button type="button" @click="goToChat">Чат</button>
    <button type="button" @click="goToDoclist">Список документов</button>
    <button type="button" @click="goToCreatedoc">Добавить документ</button>
  </div>
  <router-view />
</template>

<script>
export default {
  name: "App",
  data: function () {
    return {
      connection: null,
    };
  },
  methods: {
    goToChat() {
      this.$router.push({ name: "chat", params: { wbs: this.connection } });
    },
    goToDoclist() {
      this.$router.push("/doclist");
    },
    goToCreatedoc() {
      this.$router.push("/createdoc");
    },
  },
  created: function () {
    console.log("Подключение...");
    this.connection = new WebSocket("/ws/chat"); //   /ws/chat   ws://localhost:8080/api/v1/chat

    this.connection.onopen = function () {
      console.log("Подключение установлено.");
    };
  },
};
</script>
