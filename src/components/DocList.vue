<script>
const PAGE_SIZE = 12;

export default {
  name: "DocList",
  props: {
    baseUrl: {
      type: String,
      required: true,
    },
    refreshKey: {
      type: Number,
      default: 0,
    },
  },
  data() {
    return {
      documents: [],
      filters: {
        search: "",
      },
      pagination: {
        page: 1,
        totalPages: 1,
        total: 0,
      },
      isLoading: false,
      error: null,
    };
  },
  computed: {
    normalizedBaseUrl() {
      return this.baseUrl.replace(/\/$/, "");
    },
    hasDocuments() {
      return this.documents.length > 0;
    },
    resultSummary() {
      const total = this.pagination.total;
      if (!total) {
        return "Нет документов";
      }
      if (this.filters.search.trim()) {
        return `Найдено ${total} ${this.pluralize(total)} по запросу`;
      }
      return `Всего ${total} ${this.pluralize(total)}`;
    },
    pageNumbers() {
      const pages = [];
      const total = this.pagination.totalPages;
      const current = this.pagination.page;
      const windowSize = 2;
      const start = Math.max(1, current - windowSize);
      const end = Math.min(total, current + windowSize);

      for (let page = start; page <= end; page += 1) {
        pages.push(page);
      }

      if (!pages.includes(1)) {
        pages.unshift(1);
      }
      if (!pages.includes(total)) {
        pages.push(total);
      }

      return [...new Set(pages)].sort((a, b) => a - b);
    },
  },
  watch: {
    refreshKey() {
      this.fetchPage(1);
    },
  },
  created() {
    this.fetchPage(1);
  },
  methods: {
    pluralize(value) {
      const n = Math.abs(value) % 100;
      const n1 = n % 10;
      if (n > 10 && n < 20) {
        return "документов";
      }
      if (n1 > 1 && n1 < 5) {
        return "документа";
      }
      if (n1 === 1) {
        return "документ";
      }
      return "документов";
    },
    formatDate(value) {
      if (!value) {
        return "—";
      }
      try {
        return new Date(value).toLocaleDateString("ru-RU", {
          day: "2-digit",
          month: "long",
          year: "numeric",
        });
      } catch (error) {
        return value;
      }
    },
    async fetchPage(pageNumber = 1) {
      this.isLoading = true;
      this.error = null;

      try {
        const targetUrl = new URL("/doclist/paginated", `${this.normalizedBaseUrl}/`);
        targetUrl.searchParams.set("size", PAGE_SIZE.toString());
        targetUrl.searchParams.set("page", Math.max(pageNumber - 1, 0).toString());

        const trimmedSearch = this.filters.search.trim();
        if (trimmedSearch) {
          targetUrl.searchParams.set("search", trimmedSearch);
        }

        const response = await fetch(targetUrl.toString(), {
          headers: {
            Accept: "application/json",
          },
        });

        if (!response.ok) {
          throw new Error(`Ошибка загрузки документов: ${response.status}`);
        }

        const payload = await response.json();
        const total = payload.total ?? 0;
        const totalPages =
            payload.total_pages !== undefined
              ? Math.max(payload.total_pages, 1)
              : Math.max(Math.ceil(total / PAGE_SIZE), 1);

        this.documents = payload.items || [];
        this.pagination.total = total;
        this.pagination.totalPages = totalPages;

        if (pageNumber > totalPages && totalPages > 0) {
          this.pagination.page = totalPages;
          await this.fetchPage(totalPages);
          return;
        }

        this.pagination.page = Math.min(pageNumber, totalPages);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Не удалось загрузить список документов.";
      } finally {
        this.isLoading = false;
      }
    },
    async handleSearch() {
      await this.fetchPage(1);
    },
    clearSearch() {
      if (!this.filters.search) {
        return;
      }
      this.filters.search = "";
      this.fetchPage(1);
    },
    openDocument(id) {
      const targetUrl = new URL(`/doclist/${id}`, `${this.normalizedBaseUrl}/`);
      window.open(targetUrl.toString(), "_blank", "noopener");
    },
    async removeDocument(index) {
      const document = this.documents[index];
      if (!document) {
        return;
      }
      const confirmed = window.confirm(
        `Удалить документ ${document.id_cr} («${document.title}»)?`
      );
      if (!confirmed) {
        return;
      }

      try {
        const deleteUrl = new URL(`/doclist/${document.id_cr}`, `${this.normalizedBaseUrl}/`);
        const response = await fetch(deleteUrl.toString(), {
          method: "DELETE",
        });
        if (!response.ok) {
          throw new Error(`Не удалось удалить документ: ${response.status}`);
        }

        const shouldGoPrev =
          this.documents.length === 1 && this.pagination.page > 1;
        const nextPage = shouldGoPrev ? this.pagination.page - 1 : this.pagination.page;
        await this.fetchPage(nextPage);
      } catch (err) {
        console.error(err);
        this.error = err.message || "Не удалось удалить документ.";
      }
    },
    changePage(pageNumber) {
      if (pageNumber !== this.pagination.page) {
        this.fetchPage(pageNumber);
      }
    },
    prevPage() {
      if (this.pagination.page > 1) {
        this.fetchPage(this.pagination.page - 1);
      }
    },
    nextPage() {
      if (this.pagination.page < this.pagination.totalPages) {
        this.fetchPage(this.pagination.page + 1);
      }
    },
  },
};
</script>

<template>
  <section class="doclist">
    <header class="doclist__toolbar">
      <div class="doclist__search">
        <label class="form-label" for="doc-search">Поиск по названию или ID</label>
        <div class="search-control">
          <input
            id="doc-search"
            type="text"
            v-model="filters.search"
            placeholder="Например: гастрит или KR-001"
            @keyup.enter="handleSearch"
          />
          <button
            type="button"
            class="btn btn--ghost"
            @click="handleSearch"
          >
            Найти
          </button>
          <button
            v-if="filters.search"
            type="button"
            class="btn btn--ghost btn--icon"
            aria-label="Очистить поиск"
            @click="clearSearch"
          >
            ×
          </button>
        </div>
      </div>
      <div class="doclist__meta">
        <span class="doclist__summary">{{ resultSummary }}</span>
        <button
          type="button"
          class="btn btn--ghost"
          @click="fetchPage(pagination.page)"
        >
          Обновить
        </button>
      </div>
    </header>

    <div v-if="error" class="alert alert--error" role="alert">
      <span>{{ error }}</span>
      <button type="button" class="alert__close" @click="error = null" aria-label="Закрыть">×</button>
    </div>

    <div class="doclist__body">
      <div v-if="isLoading" class="doclist__loader">
        <span class="spinner"></span>
        <p>Загружаем документы…</p>
      </div>

      <ul v-else-if="hasDocuments" class="doclist__grid">
        <li v-for="(doc, index) in documents" :key="doc.id_cr">
          <article class="doc-card">
            <header class="doc-card__header">
              <div>
                <h3>{{ doc.title }}</h3>
                <p class="doc-card__id">ID: {{ doc.id_cr }}</p>
              </div>
              <span class="doc-card__date">{{ formatDate(doc.placement_date) }}</span>
            </header>

            <dl class="doc-card__meta">
              <div>
                <dt>МКБ-10</dt>
                <dd>{{ doc.MCB || "—" }}</dd>
              </div>
              <div>
                <dt>Возрастная категория</dt>
                <dd>{{ doc.age_category || "—" }}</dd>
              </div>
              <div>
                <dt>Разработчик</dt>
                <dd>{{ doc.developer || "—" }}</dd>
              </div>
            </dl>

            <footer class="doc-card__actions">
              <button type="button" class="btn btn--secondary" @click="openDocument(doc.id_cr)">
                Открыть
              </button>
              <button
                type="button"
                class="btn btn--danger"
                @click="removeDocument(index)"
              >
                Удалить
              </button>
            </footer>
          </article>
        </li>
      </ul>

      <div v-else class="empty-state empty-state--compact">
        <h3>Документы не найдены</h3>
        <p>Попробуйте изменить поисковый запрос или загрузить новый документ.</p>
      </div>
    </div>

    <nav
      v-if="!isLoading && pagination.totalPages > 1"
      class="pagination"
      aria-label="Навигация по страницам"
    >
      <button
        type="button"
        class="pagination__arrow"
        :disabled="pagination.page <= 1"
        @click="prevPage"
        aria-label="Предыдущая страница"
      >
        ‹
      </button>

      <button
        v-for="pageNumber in pageNumbers"
        :key="pageNumber"
        type="button"
        class="pagination__page"
        :class="{ 'pagination__page--active': pageNumber === pagination.page }"
        @click="changePage(pageNumber)"
      >
        {{ pageNumber }}
      </button>

      <button
        type="button"
        class="pagination__arrow"
        :disabled="pagination.page >= pagination.totalPages"
        @click="nextPage"
        aria-label="Следующая страница"
      >
        ›
      </button>
    </nav>
  </section>
</template>

