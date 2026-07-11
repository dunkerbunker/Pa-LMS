<template>
	<Dialog
		v-model:open="show"
		:title="isEdit ? __('Edit Member') : __('Add New Member')"
		size="lg"
		:actions="[
			{
				label: isEdit ? __('Save') : __('Add'),
				variant: 'solid',
				loading: submitting,
				onClick: ({ close }: any) => submit(close),
			},
		]"
	>
		<template #default>
			<div class="space-y-4">
				<FormControl
					v-model="member.email"
					:label="__('Email')"
					placeholder="jane@doe.com"
					type="email"
					:required="!isEdit"
					:disabled="isEdit"
					@keyup.enter="submit()"
				/>
				<div v-if="!isEdit" class="flex items-center gap-3">
					<FormControl
						v-model="member.first_name"
						:label="__('First Name')"
						placeholder="Jane"
						type="text"
						class="w-full"
					/>
					<FormControl
						v-model="member.last_name"
						:label="__('Last Name')"
						placeholder="Doe"
						type="text"
						class="w-full"
					/>
				</div>
				<div class="flex flex-col gap-2">
					<div class="text-p-sm-medium text-ink-gray-7">
						{{ __('Roles') }}
					</div>
					<div class="grid md:grid-cols-2 gap-x-6 gap-y-3">
						<BooleanSwitch
							size="sm"
							:label="__('Student')"
							v-model="roles.lms_student"
						/>
						<BooleanSwitch
							size="sm"
							:label="__('Course Creator')"
							v-model="roles.course_creator"
						/>
						<BooleanSwitch
							size="sm"
							:label="__('Evaluator')"
							v-model="roles.batch_evaluator"
						/>
						<BooleanSwitch
							size="sm"
							:label="__('Moderator')"
							v-model="roles.moderator"
						/>
					</div>
				</div>
				<MultiLink
					v-model="courseAssignments"
					doctype="LMS Course"
					:label="__('Assigned Courses')"
					:placeholder="__('Select courses')"
				/>
			</div>
		</template>
	</Dialog>
</template>

<script setup lang="ts">
import { call, Dialog, FormControl, toast } from 'frappe-ui'
import BooleanSwitch from '@/components/Controls/BooleanSwitch.vue'
import MultiLink from '@/components/Controls/MultiLink.vue'
import { computed, reactive, ref, watch } from 'vue'
import { cleanError } from '@/utils'

const show = defineModel<boolean>({ default: false })
const submitting = ref(false)

const props = defineProps<{
	defaultRoles?: string[]
	editMember?: { name: string; full_name?: string; roles?: string[] } | null
}>()

const emit = defineEmits<{
	created: [user: any]
	updated: []
}>()

const isEdit = computed(() => !!props.editMember)

const ROLE_MAP: Record<string, string> = {
	moderator: 'Moderator',
	course_creator: 'Course Creator',
	batch_evaluator: 'Batch Evaluator',
	lms_student: 'LMS Student',
}

const member = reactive({
	email: '',
	first_name: '',
	last_name: '',
})
const courseAssignments = ref<string[]>([])
const initialCourseAssignments = ref<string[]>([])

const roles = reactive({
	moderator: false,
	course_creator: false,
	batch_evaluator: false,
	lms_student: false,
})

const initialRoles = reactive({ ...roles })

const resetForm = () => {
	member.email = ''
	member.first_name = ''
	member.last_name = ''
	courseAssignments.value = []
	initialCourseAssignments.value = []
	applyDefaultRoles()
}

const applyDefaultRoles = () => {
	roles.moderator = props.defaultRoles?.includes('moderator') ?? false
	roles.course_creator = props.defaultRoles?.includes('course_creator') ?? false
	roles.batch_evaluator =
		props.defaultRoles?.includes('batch_evaluator') ?? false
	roles.lms_student = props.defaultRoles?.includes('lms_student') ?? false
}

const loadMember = () => {
	member.email = props.editMember?.name ?? ''
	member.first_name = ''
	member.last_name = ''
	const current = props.editMember?.roles ?? []
	for (const key of Object.keys(ROLE_MAP) as (keyof typeof roles)[]) {
		roles[key] = current.includes(ROLE_MAP[key])
		initialRoles[key] = roles[key]
	}
	courseAssignments.value = []
	initialCourseAssignments.value = []
	loadCourseAssignments()
}

watch(show, (isOpen) => {
	if (!isOpen) return
	if (isEdit.value) loadMember()
	else resetForm()
})

const submit = (close?: () => void) => {
	if (submitting.value) return
	return isEdit.value ? saveRoles(close) : addMember(close)
}

const selectedRoleNames = () =>
	Object.entries(roles)
		.filter(([_, checked]) => checked)
		.map(([key]) => ROLE_MAP[key])

const copyInviteLink = async (inviteUrl: string) => {
	try {
		await navigator.clipboard?.writeText(inviteUrl)
		return true
	} catch {
		return false
	}
}

const loadCourseAssignments = async () => {
	if (!props.editMember?.name) return
	try {
		const assigned = await call('lms.lms.api.get_user_course_assignments', {
			user: props.editMember.name,
		})
		courseAssignments.value = Array.isArray(assigned) ? assigned : []
		initialCourseAssignments.value = [...courseAssignments.value]
	} catch {
		courseAssignments.value = []
		initialCourseAssignments.value = []
	}
}

const addMember = async (close?: () => void) => {
	if (!member.email?.trim()) {
		toast.error(__('Email is required'))
		return
	}

	submitting.value = true
	try {
		const invite = await call('lms.lms.api.create_invite', {
			email: member.email.trim(),
			first_name: member.first_name.trim() || undefined,
			last_name: member.last_name.trim() || undefined,
			roles: selectedRoleNames(),
			courses: courseAssignments.value,
		})

		if (invite?.email_sent === false && invite?.invite_url) {
			const copied = await copyInviteLink(invite.invite_url)
			toast.success(
				copied
					? __('Invite created. Link copied to clipboard.')
					: __('Invite created. Email is not configured. Invite link: {0}').format(
							invite.invite_url,
						),
			)
		} else {
			toast.success(__('Invite sent successfully'))
		}
		emit('created', invite)
		resetForm()
		close?.()
	} catch (err: any) {
		toast.error(cleanError(err.messages?.[0]) || __('Unable to send invite'))
	} finally {
		submitting.value = false
	}
}

const saveRoles = async (close?: () => void) => {
	if (!props.editMember?.name) return

	submitting.value = true
	try {
		for (const key of Object.keys(ROLE_MAP) as (keyof typeof roles)[]) {
			if (roles[key] !== initialRoles[key]) {
				await call('lms.lms.api.save_role', {
					user: props.editMember.name,
					role: ROLE_MAP[key],
					value: roles[key] ? 1 : 0,
				})
			}
		}

		await call('lms.lms.api.update_user_course_assignments', {
			user: props.editMember.name,
			courses: courseAssignments.value,
		})
		initialCourseAssignments.value = [...courseAssignments.value]

		toast.success(__('Member updated'))
		emit('updated')
		close?.()
	} catch (err: any) {
		toast.error(cleanError(err.messages?.[0]) || __('Unable to update member'))
	} finally {
		submitting.value = false
	}
}
</script>
