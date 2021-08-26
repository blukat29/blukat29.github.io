---
layout: post
title: Deleting Azure "dangling" role assignments
category: dev
---

Azure 클라우드에서 *dangling role assignment* 가 200여개가 생겨있길래 지웠다.

청소하는 Azure CLI 스크립트는 다음과 같다.

```bash
az role assignment delete --verbose --ids $(az role assignment list --all | jq -r '.[] | if (.resourceGroup | length == 0) and (.principalName | length == 0) then .id else empty end')
```

# Role Assignment

Azure 클라우드에서 RBAC (role based access control) 은 "role assignment" 라는 단위로 정의된다. 하나의 role assignment 는 다음으로 구성된다. 자세한 내용은 [Azure Docs](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview)에 잘 나와있다.

- assignee or principal (주체): 누구에게
- scope (범위): 어디에서
- role (역할): 무엇을 하도록 허용한다

![azure-role-assignment.png](/assets/2021/08/azure-role-assignment.png)

<!--more-->

azure cli로 role assignment 하나를 살펴보겠다. Role assignment는 다음 필드를 포함하고 있는 자료구조이다.

- `id`: "role assignment"의 ID
- `principalId`: Assignee ID
- `principalName`: Assignee Name
- `scope`: Scope ID ([format](https://docs.microsoft.com/en-us/azure/role-based-access-control/scope-overview))
- `resourceGroup`: Scope가 포함된 리소스 그룹. Scope가 구독
- `roleDefinitionName`: Name of the role

```bash
$ az role assignment list | jq '.[0]'
{
  "canDelegate": null,
  "condition": null,
  "conditionVersion": null,
  "description": null,
  "id": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/DevRG/providers/Microsoft.Storage/storageAccounts/testaccount/blobServices/default/containers/backup/providers/Microsoft.Authorization/roleAssignments/22222222-2222-2222-2222-222222222222",
  "name": "22222222-2222-2222-2222-222222222222",
  "principalId": "33333333-3333-3333-3333-333333333333",
  "principalName": "http://my-build-bot",
  "principalType": "ServicePrincipal",
  "resourceGroup": "DevRG",
  "roleDefinitionId": "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1",
  "roleDefinitionName": "Storage Blob Data Reader",
  "scope": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/DevRG/providers/Microsoft.Storage/storageAccounts/testaccount/blobServices/default/containers/backup",
  "type": "Microsoft.Authorization/roleAssignments"
}
```

# Dangling role assignment 란

Dangling role assignment는 내가 만든 말인데, Role assignment가 가리키는 assignee가 없어진 경우를 그렇게 부르려고 한다 ([Dangling pointer](https://ko.wikipedia.org/wiki/%ED%97%88%EC%83%81_%ED%8F%AC%EC%9D%B8%ED%84%B0) 에서 아이디어를 얻었다). 이게 어떻게 생기냐 하면 role assignment 는 남아있는데 assignee 가 삭제되면 생긴다고 한다. User나 service principal을 삭제하더라도 연관된 role assignment가 자동으로 삭제되지 않기 때문이다.

[Azure Docs](https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#role-assignments-with-identity-not-found)에서는 이런 경우를 "Role assignments with identity not found"라고 부르고, 이를 해결하는 방법도 설명되어있다. Dangling role assignment는 assignee가 존재하지 않으므로 아무 의미 없는 role assignment이다. 따라서 있어도 그만, 없어도 그만이다.

## Azure Portal 에서 알아보기

Dangling role assignment 는 Azure Portal 에서 "Identity not found. Unable to find identity, Type Unknown" 등이 써있는 것으로 알 수 있다.

![azure-portal-dangling-role.png](/assets/2021/08/azure-portal-dangling-role.png)

## Azure CLI 에서 알아보기

Azure CLI 에서 role assignment 를 조회하다가 아래처럼 `principalName` 이 비어있으면 dangling role assignment 인 것이다.

```bash
$ az role assignment list | jq '.[0]'
{
    "canDelegate": null,
    "id": "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleAssignments/22222222-2222-2222-2222-222222222222",
    "name": "22222222-2222-2222-2222-222222222222",
    "principalId": "33333333-3333-3333-3333-333333333333",
    "principalName": "",
    "roleDefinitionId": "/subscriptions/11111111-1111-1111-1111-111111111111/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe",
    "roleDefinitionName": "Storage Blob Data Contributor",
    "scope": "/subscriptions/11111111-1111-1111-1111-111111111111",
    "type": "Microsoft.Authorization/roleAssignments"
}
```

# Dangling role assignment 삭제하기

이제 dangling role assignment 가 아무 역할도 하지 않는 다는 것을 알았으니, 모두 찾아서 지워보자.

## Azure Portal 에서 삭제하기

[Azure Docs](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-remove) 를 따라서 지울 수 있다. 그런데 Azure 에 리소스를 많이 갖고 있다면 이 방식으로는 한계가 있다.

![azure-portal-delete-role.png](/assets/2021/08/azure-portal-delete-role.png)

## Azure CLI로 삭제하기

먼저 모든 role assignment 를 조회한다.

```bash
az role assignment list --all
```

이 중에서 다음 조건에 맞는 것만 고른다

1. "dangling": principalName 이 비어있을 것. assignee인 service principal이 삭제된 것이다.
2. "global": resourceGroup 이 비어있을 것. scope가 전체, 즉 subscription이라는 뜻이다.

위 조건을 `jq` 필터로 구현한다. ([https://stedolan.github.io/jq/manual/](https://stedolan.github.io/jq/manual/))

```bash
jq -r '.[] | if (.resourceGroup | length == 0) and (.principalName | length == 0) then .id else empty end'
```

필터링한 것의 role assignment id 를 모아서 삭제 요청한다

```bash
az role assignment delete --verbose --ids $(..)
```

조립하면 다음과 같은 one-liner가 된다.

```bash
az role assignment delete --verbose --ids $(az role assignment list --all | jq -r '.[] | if (.resourceGroup | length == 0) and (.principalName | length == 0) then .id else empty end')
```

지우는 role assignment 갯수에 따라 시간이 꽤 오래 걸릴 수 있다.

# 고찰

## 왜 dangling role assignment가 발생하는가?

Azure CLI 에서 `az ad sp delete` 로 service principal 을 지우면 자동으로 연관된 role assignment가 삭제된다. 따라서 이 과정에서 생기진 않았을 것이다.

```bash
$ az ad sp delete --id 33333333-3333-3333-3333-333333333333
Removing role assignments
```

[Jesse Loudon 씨는 2020년에](https://purple.telstra.com/blog/removing-unknown-azure-rbac-role-assignments-with-powershell) Azure Policy 리소스를 삭제하면서 managed identity 가 삭제되면 이런 현상이 발생한다고 보고한 바 있다. 아마도 Azure 내부 로직에서 role assignment 삭제를 빠트린 것이 아닐까. 그렇다면 dangling role assignment가 생기지 않도록 예방하는 건 불가능할 것 같다.

## Dangling role assignment는 유해한가?

물론 아무에게도 권한을 주지 않기때문에 보안상 문제는 없을 것이다.

하지만 아무 역할도 없이 Azure 구독의 role assignment 갯수를 잡아먹기 때문에 문제가 될 수 있다.

아래에서 보듯이 구독마다 role assignent의 개수는 2,000개로 제한돼있다. [2,000개 제한은 고정이고 바꿀 수 없다고 한다](https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#azure-role-assignments-limit). 제한에 걸리면 RoleAssignmentLimitExceeded 라는 에러가 나면서 role assignment 생성이 실패한다고 한다.

![azure-portal-role-limit.png](/assets/2021/08/azure-portal-role-limit.png)

따라서 가끔씩 위의 one-liner 청소 스크립트를 돌려주는 것으로 관리해주는 것도 좋겠다.

