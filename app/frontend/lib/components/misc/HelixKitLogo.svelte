<script>
  let { class: className = '', ...restProps } = $props();
</script>

<div class="flex items-center gap-2 {className}" {...restProps}>
  <div class="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center shadow-sm shrink-0">
    <svg class="w-4 h-4 text-white" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <path
        d="M2 13L14 3M14 3H7M14 3V10"
        stroke="currentColor"
        stroke-width="1.8"
        stroke-linecap="round"
        stroke-linejoin="round"></path>
    </svg>
  </div>
  <span class="text-sm font-semibold tracking-wide">RunwayLite</span>
</div>
