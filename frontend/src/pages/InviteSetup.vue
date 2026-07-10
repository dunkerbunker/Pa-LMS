<template>
	<div
		class="flex min-h-screen items-center justify-center bg-surface-base px-4 py-10"
	>
		<div
			class="w-full max-w-md rounded border border-outline-gray-2 bg-surface-base p-6 shadow-sm"
		>
			<div class="mb-6 space-y-1">
				<h1 class="text-2xl-semibold text-ink-gray-9">
					{{ __('Complete your profile') }}
				</h1>
				<p class="text-p-base text-ink-gray-6">
					{{ inviteLabel }}
				</p>
			</div>

			<div v-if="invite.loading" class="py-8 text-center text-ink-gray-6">
				{{ __('Checking invite...') }}
			</div>
			<div
				v-else-if="inviteError"
				class="rounded bg-surface-red-1 p-3 text-p-base text-ink-red-4"
			>
				{{ inviteError }}
			</div>
			<form v-else class="space-y-4" @submit.prevent="acceptInvite">
				<FormControl
					v-model="profile.first_name"
					:label="__('First Name')"
					type="text"
					required
				/>
				<FormControl
					v-model="profile.last_name"
					:label="__('Last Name')"
					type="text"
				/>
				<FormControl
					v-model="profile.password"
					:label="__('Password')"
					type="password"
					required
				/>
				<FormControl
					v-model="profile.confirm_password"
					:label="__('Confirm Password')"
					type="password"
					required
				/>
				<Button
					variant="solid"
					class="w-full"
					:loading="submitting"
					@click="acceptInvite"
				>
					{{ __('Create Account') }}
				</Button>
			</form>
		</div>
	</div>
</template>

<script setup lang="ts">
import { Button, FormControl, call, createResource, toast } from 'frappe-ui'
import { computed, reactive, ref } from 'vue'
import { cleanError } from '@/utils'

const props = defineProps<{
	token: string
}>()

const submitting = ref(false)
const inviteError = ref('')

const profile = reactive({
	first_name: '',
	last_name: '',
	password: '',
	confirm_password: '',
})

const invite = createResource({
	url: 'lms.lms.api.get_invite',
	makeParams() {
		return {
			token: props.token,
		}
	},
	auto: true,
	onSuccess(data: { first_name?: string; last_name?: string }) {
		profile.first_name = data?.first_name || ''
		profile.last_name = data?.last_name || ''
		inviteError.value = ''
	},
	onError(err: any) {
		inviteError.value =
			cleanError(err.messages?.[0]) ||
			__('This invite is invalid, expired, or already used.')
	},
})

const inviteLabel = computed(() => {
	if (invite.data?.email) {
		return __('Set your name and password for {0}.').format(invite.data.email)
	}
	return __('Set your name and password to access your assigned courses.')
})

const acceptInvite = async () => {
	if (!profile.first_name?.trim()) {
		toast.error(__('First name is required'))
		return
	}
	if (!profile.password) {
		toast.error(__('Password is required'))
		return
	}
	if (profile.password !== profile.confirm_password) {
		toast.error(__('Passwords do not match'))
		return
	}

	submitting.value = true
	try {
		await call('lms.lms.api.accept_invite', {
			token: props.token,
			first_name: profile.first_name.trim(),
			last_name: profile.last_name.trim(),
			password: profile.password,
		})
		toast.success(__('Account created. Please log in.'))
		window.location.href = '/login'
	} catch (err: any) {
		toast.error(
			cleanError(err.messages?.[0]) || __('Unable to complete invite setup'),
		)
	} finally {
		submitting.value = false
	}
}
</script>
