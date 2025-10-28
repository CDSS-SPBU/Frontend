import { createRouter, createWebHashHistory } from "vue-router";
import ChatView from "../views/ChatView.vue";
import DoclistView from "../views/DoclistView.vue";
import CreatedocView from "../views/CreatedocView.vue";

const routes = [
  {
    path: "/chat",
    name: "chat",
    component: ChatView,
    props: true,
  },
  {
    path: "/doclist",
    name: "doclist",
    component: DoclistView,
  },
  {
    path: "/createdoc",
    name: "createdoc",
    component: CreatedocView,
  },
  /*{
    path: "/",
    name: "default",
    component: DefaultView,
  },*/
];

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

export default router;
