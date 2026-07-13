<template>
	<Dialog
		v-model:open="show"
		:title="__('Write a Review')"
		size="xl"
		:actions="[
			{
				label: 'Submit',
				variant: 'solid',
				onClick: ({ close }) => submitReview(close),
			},
		]"
	>
		<template #default>
			<div class="flex flex-col gap-4">
				<Rating v-model="review.rating" :label="__('Rating')" />
				<FormControl
					:label="__('Review')"
					type="textarea"
					v-model="review.review"
					:rows="5"
				/>
			</div>
		</template>
	</Dialog>
</template>
<script setup lang="ts">
import { Dialog, FormControl, createResource, toast, Rating } from 'frappe-ui'
import { reactive } from 'vue'
import type { Resource } from '@/types/api'

const show = defineModel<boolean>()
const reviews = defineModel<Resource<unknown> | undefined>('reloadReviews')
const hasReviewed = defineModel<Resource<unknown> | undefined>('hasReviewed')

const review = reactive<{ review: string; rating: number }>({
	review: '',
	rating: 0,
})

const props = defineProps<{
	courseName: string
}>()

const createReview = createResource({
	url: 'lms.lms.doctype.lms_course_review.lms_course_review.submit_review',
	makeParams() {
		return {
			course: props.courseName,
			review: review.review,
			// the Rating control is 0–5; the doctype stores a 0–1 fraction
			rating: review.rating / 5,
		}
	},
})

function submitReview(close: () => void) {
	createReview.submit(review, {
		validate() {
			if (!review.rating) {
				return 'Please enter a rating.'
			}
		},
		onSuccess() {
			reviews.value?.reload()
			hasReviewed.value?.reload()
			close()
		},
		onError(err: { messages?: string[]; message?: string } | string) {
			const msg =
				typeof err === 'string'
					? err
					: err.messages?.[0] ?? err.message ?? __('Something went wrong.')
			toast.error(msg)
		},
	})
}
</script>
