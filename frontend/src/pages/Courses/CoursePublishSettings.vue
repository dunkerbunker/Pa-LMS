<template>
	<div class="">
		<CollapsibleSection :label="__('Visibility')">
			<div class="flex flex-col gap-y-4">
				<BooleanSwitch
					size="sm"
					v-model="doc.upcoming"
					:label="__('Upcoming')"
					:description="__('Not yet open for enrollment.')"
					@update:modelValue="markDirty()"
				/>
				<BooleanSwitch
					size="sm"
					v-model="doc.featured"
					:label="__('Featured')"
					:description="__('Highlight on the homepage.')"
					@update:modelValue="markDirty()"
				/>
			</div>
		</CollapsibleSection>

		<CollapsibleSection :label="__('Certification')">
			<div class="flex flex-col gap-y-4">
				<div class="border-t -mx-5" />
				<BooleanSwitch
					size="sm"
					v-model="doc.enable_certification"
					:label="__('Completion certificate')"
					:description="
						__('Issue a certificate when learners complete the course.')
					"
					@update:modelValue="markDirty()"
				/>

				<div
					v-if="doc?.enable_certification"
					class="flex flex-wrap items-center gap-1 text-p-sm text-ink-gray-6"
				>
					<span>
						{{
							__(
								'Certificates render from a Print Format. Build or customize templates from the desk.',
							)
						}}
					</span>
					<button
						type="button"
						class="font-medium text-ink-gray-8 underline"
						@click="openPrintFormats"
					>
						{{ __('Manage templates') }}
					</button>
				</div>
			</div>
		</CollapsibleSection>
	</div>
</template>

<script setup lang="ts">
import BooleanSwitch from '@/components/Controls/BooleanSwitch.vue'
import { computed, inject } from 'vue'
import CollapsibleSection from '@/components/CollapsibleSection.vue'
import type { CourseFormContext } from '@/types/api'

const { resource, markDirty } = inject<CourseFormContext>('courseForm')!

const doc = computed(() => resource.doc)

function openPrintFormats() {
	window.open('/app/print-format?doc_type=LMS Certificate', '_blank')
}
</script>
