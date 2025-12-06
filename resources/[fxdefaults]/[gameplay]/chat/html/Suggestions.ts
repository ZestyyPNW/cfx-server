import CONFIG from './config';
import Vue, { PropType } from 'vue';

export interface Suggestion {
  name: string;
  help: string;
  params: string[];

  disabled: boolean;
}

export default Vue.component('suggestions', {
  props: {
    message: {
      type: String
    },

    suggestions: {
      type: Array as PropType<Suggestion[]>
    },

    selectedIndex: {
      type: Number,
      default: -1
    }
  },
  data() {
    return {};
  },
  computed: {
    currentSuggestions(): Suggestion[] {
      return this.suggestions;
    },
  },
  methods: {},
});
