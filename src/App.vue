<script>
import DocList from "./components/DocList.vue";
import CreateDoc from "./components/CreateDoc.vue";

const resolveApiBaseUrl = () => {
  const envUrl = (process.env.VUE_APP_API_BASE_URL || "").trim();

  const hasWindow = typeof window !== "undefined" && typeof window.location !== "undefined";
  const fallbackBase = hasWindow
    ? (() => {
        const { protocol, hostname, port } = window.location;

        const pickBackendPort = () => {
          if (!port) {
            return "8002";
          }
          if (["80", "443", "8080"].includes(port)) {
            return "8002";
          }
          return port;
        };

        const backendPort = pickBackendPort();
        return `${protocol}//${hostname}:${backendPort}`;
      })()
    : "http://localhost:8002";

  if (envUrl) {
    try {
      const url = new URL(envUrl);
      if (!hasWindow) {
        return url.origin.replace(/\/$/, "");
      }
      const currentHost = window.location.hostname;
      const allowedHosts = new Set([currentHost, "localhost", "127.0.0.1"]);
      if (url.hostname.includes(".") || allowedHosts.has(url.hostname)) {
        return url.origin.replace(/\/$/, "");
      }
      console.warn(
        `Игнорируем VUE_APP_API_BASE_URL (${envUrl}): хост недоступен из браузера. Используется ${fallbackBase}.`
      );
    } catch (error) {
      console.warn("Некорректное значение VUE_APP_API_BASE_URL, используем fallback", error);
    }
  }

  return fallbackBase.replace(/\/$/, "");
};

const DEFAULT_BASE_URL = resolveApiBaseUrl();

function buildWebSocketUrl(baseUrl) {
  try {
    const url = new URL(baseUrl);
    const protocol = url.protocol === "https:" ? "wss:" : "ws:";
    return `${protocol}//${url.host}/ws/chat`;
  } catch (error) {
    console.warn("Не удалось сформировать WebSocket URL, используем по умолчанию", error);
    const sanitized = baseUrl.replace(/^https?:\/\//, "");
    return `ws://${sanitized}/ws/chat`;
  }
}

export default {
  name: "App",
  components: {
    DocList,
    CreateDoc,
  },
  data() {
    return {
      apiBaseUrl: DEFAULT_BASE_URL,
      websocketUrl: buildWebSocketUrl(DEFAULT_BASE_URL),
      connection: null,
      connectionStatus: "connecting",
      reconnectTimer: null,
      messages: [],
      sessionId: null,
      currentView: "chat",
      query: "",
      errorMessage: null,
      isSending: false,
      doclistRefreshKey: 0,
      shouldScrollChatBottom: true,
    };
  },
  computed: {
    connectionStatusLabel() {
      switch (this.connectionStatus) {
        case "online":
          return "Онлайн";
        case "connecting":
          return "Подключаемся…";
        case "offline":
          return "Ожидаем переподключения";
        case "error":
        default:
          return "Ошибка соединения";
      }
    },
    connectionBadgeClass() {
      return `status-badge status-badge--${this.connectionStatus}`;
    },
    isChatView() {
      return this.currentView === "chat";
    },
    isDocumentsView() {
      return this.currentView === "documents";
    },
    isUploadView() {
      return this.currentView === "upload";
    },
  },
  watch: {
    messages() {
      this.$nextTick(() => this.scrollChatToBottom());
    },
    currentView(newView) {
      if (newView === "chat") {
        this.$nextTick(() => {
          if (this.shouldScrollChatBottom) {
            this.scrollChatToBottom(true);
          }
          this.shouldScrollChatBottom = true;
        });
      }
    },
  },
  mounted() {
    this.connectWebSocket();
  },
  beforeUnmount() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.connection) {
      this.connection.close();
      this.connection = null;
    }
  },
  methods: {
    setView(view, options = {}) {
      const { scrollChatBottom = true } = options;
      this.shouldScrollChatBottom = scrollChatBottom;
      this.currentView = view;
      if (view !== "chat") {
        this.shouldScrollChatBottom = true;
      }
    },
    handleLogoClick() {
      if (this.currentView !== "chat") {
        this.setView("chat", { scrollChatBottom: false });
      } else {
        this.shouldScrollChatBottom = false;
      }
      if (typeof window !== "undefined" && typeof window.scrollTo === "function") {
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
      this.$nextTick(() => {
        this.shouldScrollChatBottom = true;
      });
    },
    connectWebSocket() {
      if (this.connection) {
        this.connection.close();
      }

      this.connectionStatus = "connecting";
      this.errorMessage = null;
      const ws = new WebSocket(this.websocketUrl);
      this.connection = ws;

      ws.addEventListener("open", () => {
        this.connectionStatus = "online";
      });

      ws.addEventListener("message", (event) => {
        this.handleIncomingMessage(event);
      });

      ws.addEventListener("error", (event) => {
        console.error("WebSocket error:", event);
        this.connectionStatus = "error";
        this.errorMessage =
          "Не удалось установить соединение с чатом. Переподключаемся...";
      });

      ws.addEventListener("close", () => {
        if (this.connectionStatus !== "offline") {
          this.connectionStatus = "offline";
        }
        this.scheduleReconnect();
      });
    },
    scheduleReconnect() {
      if (this.reconnectTimer) {
        clearTimeout(this.reconnectTimer);
      }
      this.reconnectTimer = setTimeout(() => {
        if (this.connectionStatus !== "online") {
          this.connectWebSocket();
        }
      }, 3000);
    },
    handleIncomingMessage(event) {
      let payload;
      try {
        payload = JSON.parse(event.data);
      } catch (error) {
        console.warn("Получено сообщение в неверном формате", error);
        return;
      }

      if (payload.type === "session_created") {
        this.sessionId = payload.session_id;
        return;
      }

      if (payload.type === "history") {
        this.messages = Array.isArray(payload.messages) ? payload.messages : [];
        this.$nextTick(() => this.scrollChatToBottom(true));
        return;
      }

      if (payload.type === "chat_message") {
        this.messages = [
          ...this.messages,
          {
            role: payload.role,
            content: payload.content,
            timestamp: payload.timestamp || new Date().toISOString(),
          },
        ];
        this.$nextTick(() => this.scrollChatToBottom());
        return;
      }

      if (payload.type === "error") {
        this.errorMessage =
          payload.message || "Произошла ошибка при обработке запроса.";
        return;
      }

      console.debug("Получен неизвестный тип сообщения:", payload);
    },
    sendMessage() {
      const trimmedQuery = (this.query || "").trim();
      if (!trimmedQuery) {
        return;
      }

      if (!this.connection || this.connection.readyState !== WebSocket.OPEN) {
        this.errorMessage =
          "Соединение с чатом отсутствует. Идёт переподключение...";
        this.connectWebSocket();
        return;
      }

      this.isSending = true;
      this.connection.send(
        JSON.stringify({
          type: "chat_message",
          query: trimmedQuery,
        })
      );
      this.messages = [
        ...this.messages,
        {
          role: "user",
          content: trimmedQuery,
          timestamp: new Date().toISOString(),
        },
      ];
      this.query = "";
      this.$nextTick(() => this.scrollChatToBottom(true));
      this.isSending = false;
    },
    onQueryKeydown(event) {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        this.sendMessage();
      }
    },
    formatTimestamp(value) {
      if (!value) {
        return "";
      }
      try {
        return new Date(value).toLocaleString("ru-RU", {
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        });
      } catch (error) {
        return value;
      }
    },
    formatRole(role) {
      return role === "bot" ? "Ассистент" : "Врач";
    },
    clearError() {
      this.errorMessage = null;
    },
    scrollChatToBottom(force = false) {
      const container = this.$refs.chatHistory;
      if (!container) {
        return;
      }
      const distanceToBottom = container.scrollHeight - container.scrollTop - container.clientHeight;
      if (force || distanceToBottom < 160) {
        container.scrollTop = container.scrollHeight;
      }
    },
    handleDocUploaded() {
      this.setView("documents");
      this.doclistRefreshKey += 1;
    },
  },
};
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <button
        type="button"
        class="app-logo"
        @click="handleLogoClick"
        aria-label="Вернуться к началу страницы"
      >
        <span class="app-logo__icon">⚕️</span>
        <div class="app-logo__text">
          <h1>Clinical Assistant</h1>
          <p>Система поддержки врачебных решений</p>
        </div>
      </button>
      <div class="app-header__meta">
        <span :class="connectionBadgeClass">{{ connectionStatusLabel }}</span>
      </div>
    </header>

    <div class="app-content">
      <nav class="app-nav">
        <button
          class="tab-button"
          :class="{ 'tab-button--active': isChatView }"
          type="button"
          @click="setView('chat')"
        >
          <span class="tab-button__icon">💬</span>
          <span>Чат ассистента</span>
        </button>
        <button
          class="tab-button"
          :class="{ 'tab-button--active': isDocumentsView }"
          type="button"
          @click="setView('documents')"
        >
          <span class="tab-button__icon">📚</span>
          <span>Библиотека документов</span>
        </button>
        <button
          class="tab-button"
          :class="{ 'tab-button--active': isUploadView }"
          type="button"
          @click="setView('upload')"
        >
          <span class="tab-button__icon">⬆️</span>
          <span>Добавить документ</span>
        </button>
      </nav>

      <main class="app-main">
        <section v-if="isChatView" class="card card--chat">
          <header class="card__header">
            <div>
              <h2>Диалог с ассистентом</h2>
              <p>Задайте вопрос и получите рекомендации из клинических справочников.</p>
            </div>
            <span v-if="sessionId" class="session-chip">Сессия {{ sessionId }}</span>
          </header>

          <div class="card__body chat-panel">
            <div
              v-if="errorMessage"
              class="alert alert--error"
              role="alert"
            >
              <span>{{ errorMessage }}</span>
              <button
                type="button"
                class="alert__close"
                aria-label="Скрыть сообщение об ошибке"
                @click="clearError"
              >
                ×
              </button>
            </div>

            <div class="chat-history" ref="chatHistory">
              <div v-if="!messages.length" class="empty-state">
                <h3>Начните разговор</h3>
                <p>
                  Например: <br />
                  <span class="empty-state__example">
                    «Чем лечить пациента с защемлением позвоночного нерва?»
                  </span>
                </p>
              </div>

              <article
                v-for="(msg, index) in messages"
                :key="`${msg.timestamp}-${index}`"
                :class="['chat-message', `chat-message--${msg.role}`]"
              >
                <header class="chat-message__header">
                  <span class="chat-message__author">{{ formatRole(msg.role) }}</span>
                  <time class="chat-message__time">{{ formatTimestamp(msg.timestamp) }}</time>
                </header>
                <p class="chat-message__text">
                  {{ msg.content }}
                </p>
              </article>
            </div>
          </div>

          <footer class="chat-composer">
            <label class="chat-composer__label" for="chat-input">Ваш запрос</label>
            <div class="chat-composer__controls">
              <textarea
                id="chat-input"
                placeholder="Опишите клинический случай..."
                v-model="query"
                @keydown="onQueryKeydown"
                :disabled="isSending"
              ></textarea>
              <button
                type="button"
                class="btn btn--primary"
                @click="sendMessage"
                :disabled="isSending || !query.trim()"
              >
                <span v-if="isSending" class="btn__spinner"></span>
                <span>{{ isSending ? "Отправляем…" : "Отправить" }}</span>
              </button>
            </div>
            <p class="chat-composer__hint">Shift + Enter — перенос строки</p>
          </footer>
        </section>

        <section v-else-if="isDocumentsView" class="card">
          <DocList
            :base-url="apiBaseUrl"
            :refresh-key="doclistRefreshKey"
          />
        </section>

        <section v-else class="card">
          <CreateDoc
            :base-url="apiBaseUrl"
            @uploaded="handleDocUploaded"
          />
        </section>
      </main>
    </div>

    <footer class="app-footer">
      <div class="app-footer__brand">
        <span class="app-footer__logo">⚕️</span>
        <div>
          <h4>Clinical Assistant</h4>
          <p>Цифровой помощник, создающий доверие между клиническими данными и решением врача.</p>
          <small>© 2025 Medical Support Lab</small>
        </div>
      </div>

      <div class="app-footer__links">
        <h4>Ресурсы</h4>
        <a :href="`${apiBaseUrl}/docs`" target="_blank" rel="noopener">Swagger API</a>
        <a :href="`${apiBaseUrl}/doclist/paginated?size=10&page=0`" target="_blank" rel="noopener">Просмотр документов</a>
        <a href="https://cr.minzdrav.gov.ru/clin-rec" target="_blank" rel="noopener">Клинические рекомендации</a>
      </div>

      <div class="app-footer__note">
        <h4>Контакты</h4>
        <a class="app-footer__mail" href="mailto:support@clinical-assistant.dev">support@clinical-assistant.dev</a>
        <p class="app-footer__status">
          Статус соединения: <strong>{{ connectionStatusLabel }}</strong>
        </p>
      </div>
    </footer>
  </div>
</template>

