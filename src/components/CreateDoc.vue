<script>
const initialForm = () => ({
  doc_id: "",
  title: "",
  mcb: "",
  age_category: "Взрослые",
  developer: "",
  file: null,
});

export default {
  name: "CreateDoc",
  props: {
    baseUrl: {
      type: String,
      required: true,
    },
  },
  emits: ["uploaded"],
  data() {
    return {
      form: initialForm(),
      isSubmitting: false,
      statusMessage: null,
      statusType: null,
    };
  },
  computed: {
    normalizedBaseUrl() {
      return this.baseUrl.replace(/\/$/, "");
    },
    isReadyToSubmit() {
      return Boolean(this.form.doc_id && this.form.title && this.form.file);
    },
    fileName() {
      if (!this.form.file) {
        return null;
      }
      const name = this.form.file.name;
      return name.length > 40 ? `${name.slice(0, 37)}…` : name;
    },
  },
  methods: {
    handleFileChange(event) {
      const [file] = event.target.files || [];
      this.form.file = file || null;
    },
    resetForm() {
      this.form = initialForm();
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = "";
      }
      this.setStatus(null, null);
    },
    setStatus(message, type) {
      this.statusMessage = message;
      this.statusType = type;
    },
    async submitForm() {
      if (!this.isReadyToSubmit) {
        this.setStatus("Заполните обязательные поля и выберите PDF-файл.", "error");
        return;
      }

      this.isSubmitting = true;
      this.setStatus(null, null);

      try {
        const formData = new FormData();
        Object.entries(this.form).forEach(([key, value]) => {
          if (value !== null && value !== undefined) {
            formData.append(key, value);
          }
        });

        const response = await fetch(`${this.normalizedBaseUrl}/createdoc`, {
          method: "POST",
          body: formData,
        });

        if (!response.ok) {
          const payload = await response.json().catch(() => ({}));
          throw new Error(payload.detail || `Ошибка загрузки документа: ${response.status}`);
        }

        const payload = await response.json();
        this.setStatus(
          `Документ «${payload.title || this.form.title}» успешно загружен.`,
          "success"
        );
        this.$emit("uploaded");
        this.resetForm();
      } catch (err) {
        console.error(err);
        this.setStatus(err.message || "Не удалось загрузить документ.", "error");
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <section class="upload">
    <header class="section-header">
      <div>
        <h2>Добавить документ</h2>
        <p>Загрузите PDF-файл клинических рекомендаций вместе с метаданными.</p>
      </div>
    </header>

    <form class="form" @submit.prevent="submitForm" novalidate>
      <div class="form-grid">
        <label class="form-field">
          <span class="form-label">ID документа <span class="required">*</span></span>
          <input
            type="text"
            name="doc_id"
            v-model="form.doc_id"
            required
            placeholder="KR-001"
          />
        </label>

        <label class="form-field">
          <span class="form-label">Наименование <span class="required">*</span></span>
          <input
            type="text"
            name="title"
            v-model="form.title"
            required
            placeholder="Клинические рекомендации по..."
          />
        </label>

        <label class="form-field">
          <span class="form-label">МКБ-10</span>
          <input
            type="text"
            name="mcb"
            v-model="form.mcb"
            placeholder="Например: M54.5"
          />
        </label>

        <label class="form-field">
          <span class="form-label">Возрастная категория</span>
          <input
            type="text"
            name="age_category"
            v-model="form.age_category"
            placeholder="Взрослые / Дети"
          />
        </label>

        <label class="form-field form-field--wide">
          <span class="form-label">Разработчик</span>
          <input
            type="text"
            name="developer"
            v-model="form.developer"
            placeholder="Национальный медицинский исследовательский центр..."
          />
        </label>
      </div>

      <div class="form-field form-field--file">
        <span class="form-label">PDF-файл <span class="required">*</span></span>
        <label class="dropzone">
          <input
            type="file"
            name="file"
            accept=".pdf"
            required
            @change="handleFileChange"
            ref="fileInput"
          />
          <span v-if="fileName" class="dropzone__file">{{ fileName }}</span>
          <span v-else class="dropzone__hint">
            Перетащите файл сюда или нажмите, чтобы выбрать PDF (до 20 МБ)
          </span>
        </label>
      </div>

      <div class="form-actions">
        <button
          type="submit"
          class="btn btn--primary"
          :disabled="isSubmitting || !isReadyToSubmit"
        >
          <span v-if="isSubmitting" class="btn__spinner"></span>
          <span>{{ isSubmitting ? "Загружаем…" : "Загрузить документ" }}</span>
        </button>
        <button
          type="button"
          class="btn btn--ghost"
          @click="resetForm"
          :disabled="isSubmitting"
        >
          Очистить форму
        </button>
      </div>

      <p
        v-if="statusMessage"
        class="form-status"
        :class="{
          'form-status--success': statusType === 'success',
          'form-status--error': statusType === 'error',
        }"
      >
        {{ statusMessage }}
      </p>
    </form>

    <aside class="upload-hint">
      <h3>Требования к файлу</h3>
      <ul>
        <li>Формат PDF, без пароля и ограничений на копирование.</li>
        <li>Размер файла не более 20 МБ.</li>
        <li>Документ должен содержать актуальные клинические рекомендации.</li>
        <li>Заполните метаданные — они используются для поиска и ссылок.</li>
      </ul>
    </aside>
  </section>
</template>

