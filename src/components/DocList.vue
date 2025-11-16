<template>
  <textarea
    id="search"
    placeholder="Введите название документа"
    v-model="inp"
  ></textarea>
  <button id="srch-btn" type="button" @click="searchDoc">
    <svg view-box="0 0 25 25" stroke="black" stroke-width="1px">
      <circle cx="11" cy="10" r="10" fill="none"></circle>
      <path d="M18.07,17.07L25,25"></path>
    </svg>
  </button>
  <ul class="feed" id="doc-feed">
    <li v-for="(value, ind) in dList" :key="value.id_cr">
      <button id="open-btn" @click="opdoc(value.id_cr)">
        {{ value.id_cr }} | {{ value.title }}
      </button>
      <button id="del-btn" type="button" @click="del(ind)">Удалить</button>
    </li>
  </ul>
  <div id="pg-box" v-if="Page">
    <button type="button" @click="prev" v-if="Page > 1">Предыдущая</button>
    <p>{{ Page }}</p>
    <button type="button" @click="next" v-if="Page < maxP">Следующая</button>
  </div>
</template>

<script>
export default {
  name: "DocList",
  data: function () {
    return {
      dList: [
        /*{ id_cr: "932_1", title: "Описторхоз у взрослых и детей" },
        {
          id_cr: "934_1",
          title:
            "Трансплантация почки, наличие трансплантированной почки, отмирание и отторжение трансплантата почки",
        },
        { id_cr: "930_1", title: "Эритемы" },
        { id_cr: "77_3", title: "какое-то наименование" },
        { id_cr: "554_1", title: "какое-то второе наименование" },
        { id_cr: "877_3", title: "какое-то наименование номер три" },
        { id_cr: "101_0", title: "какое-то четвёртое наименование" },
        { id_cr: "874_3", title: "какое-то наименование номер пять" },
        { id_cr: "181_0", title: "какое-то шестое наименование" },
        { id_cr: "477_3", title: "какое-то наименование номер семь" },
        { id_cr: "197_0", title: "какое-то восьмое наименование" },*/
      ],
      inp: null,
      Page: 1,
      maxP: 1,
    };
  },
  created: function () {
    this.getpage();
  },
  methods: {
    del(ind) {
      const url = "//localhost:8000/doclist/" + this.dList[ind].id_cr;
      fetch(url, {
        method: "DELETE",
      });
      console.log(this.dList[ind].id_cr, " got deleted.");
      if (this.Page) {
        this.getpage();
        if (this.Page >= this.maxP && this.Page > 1) {
          this.prev();
        }
      } else {
        this.dList.splice(ind, 1);
      }
    },
    prev() {
      --this.Page;
      this.getpage();
    },
    next() {
      ++this.Page;
      this.getpage();
    },
    async getpage() {
      const url =
        "//localhost:8000/doclist/paginated?size=100&page=" +
        (this.Page - 1).toString();
      try {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`Response status: ${response.status}`);
        }
        const data = await response.json();
        this.dList = data.items;
        this.maxP = data.total_pages;
      } catch (error) {
        console.error(error.message);
      }
    },
    async opdoc(id) {
      const url = "//localhost:8000/doclist/" + id;
      try {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`Response status: ${response.status}`);
        }
      } catch (error) {
        console.error(error.message);
      }
    },
    async searchDoc() {
      if (this.inp) {
        this.dList = [];
        const url = "//localhost:8000/doclist/paginated?size=100&page=";
        try {
          for (this.Page = 0; this.Page < this.maxP; ++this.Page) {
            const response = await fetch(url + this.Page.toString());
            if (!response.ok) {
              throw new Error(`Response status: ${response.status}`);
            }
            const data = await response.json();
            this.maxP = data.total_pages;
            data.items.forEach((element) => {
              if (
                element.id_cr.includes(this.inp) ||
                element.title.includes(this.inp)
              ) {
                this.dList.push(element);
              }
            });
          }
          this.Page = 0;
        } catch (error) {
          console.error(error.message);
        }
      } else {
        this.Page = 1;
        this.getpage();
      }
    },
  },
};
</script>
